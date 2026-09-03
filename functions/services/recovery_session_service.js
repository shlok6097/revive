const crypto = require("crypto");
const admin = require("firebase-admin");

/**
 * Deterministic customer-facing messaging templates based on strategy.
 * SECURITY INVARIANT:
 * AI produces advisory classification only. Customer payment messages must
 * always be resolved through deterministic, human-verified templates.
 */
const CUSTOMER_TEMPLATES = {
  RETRY: {
    title: "Payment could not be completed",
    message: "We couldn't complete your payment. Please try again.",
    actionPrompt: "Try Payment Again",
    allowAlternate: true,
  },
  ALTERNATIVE_METHOD: {
    title: "Payment method unavailable",
    message: "We couldn't complete your payment using this method. You can try another payment method.",
    actionPrompt: "Use Another Method",
    allowAlternate: true,
  },
  WAIT_AND_RETRY: {
    title: "Temporary bank downtime",
    message: "Your payment could not be completed right now. Please try again shortly.",
    actionPrompt: "Try Again Shortly",
    allowAlternate: true,
  },
  ESCALATE: {
    title: "Payment assistance required",
    message: "We're unable to complete this payment right now. Please contact support.",
    actionPrompt: "Contact Support",
    allowAlternate: false,
  },
};

/**
 * Service managing cryptographically secure, single-use, time-bound customer recovery sessions.
 */
class RecoverySessionService {
  constructor({ firestore = null, defaultExpiryMinutes = 30 } = {}) {
    this.firestore = firestore || (admin.apps.length ? admin.firestore() : null);
    this.defaultExpiryMinutes = defaultExpiryMinutes;
  }

  get db() {
    if (!this.firestore) {
      if (!admin.apps.length) admin.initializeApp();
      this.firestore = admin.firestore();
    }
    return this.firestore;
  }

  /**
   * Hashes a raw recovery token using SHA-256.
   */
  hashToken(token) {
    if (!token || typeof token !== "string") return "";
    return crypto.createHash("sha256").update(token).digest("hex");
  }

  /**
   * Generates a 32-byte cryptographically secure random hex token.
   */
  generateToken() {
    return crypto.randomBytes(32).toString("hex");
  }

  /**
   * Resolves a customer-safe message based on recovery strategy.
   */
  getCustomerTemplate(strategy) {
    const strat = (strategy || "RETRY").toUpperCase();
    return CUSTOMER_TEMPLATES[strat] || CUSTOMER_TEMPLATES.RETRY;
  }

  /**
   * Creates a new, cryptographically secure recovery session.
   */
  async createRecoverySession({
    merchantId,
    transactionId,
    recoveryAttemptId = null,
    customerId = null,
    strategy = "RETRY",
  }) {
    if (!merchantId || !transactionId) {
      throw new Error("Both merchantId and transactionId are required to create a recovery session.");
    }

    // 1. Verify transaction ownership
    const txRef = this.db.collection("transactions").doc(transactionId);
    const txDoc = await txRef.get();
    if (txDoc.exists) {
      const txData = txDoc.data();
      if (txData.merchantId && txData.merchantId !== merchantId) {
        throw new Error("Merchant is not authorized to create a recovery session for this transaction.");
      }
    }

    // 2. Generate secure token and its SHA-256 hash
    const token = this.generateToken();
    const tokenHash = this.hashToken(token);

    const sessionId = `ses_${Date.now()}_${crypto.randomBytes(4).toString("hex")}`;
    const expiresAt = new Date(Date.now() + this.defaultExpiryMinutes * 60 * 1000);
    const now = new Date();

    // 3. Persist session with tokenHash (NEVER store raw token)
    const sessionData = {
      merchantId,
      transactionId,
      customerId: customerId || (txDoc.exists ? txDoc.data().customerId || null : null),
      recoveryAttemptId: recoveryAttemptId || null,
      strategy: strategy || "RETRY",
      status: "ACTIVE",
      tokenHash,
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      usedAt: null,
      createdAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: admin.firestore.Timestamp.fromDate(now),
    };

    await this.db.collection("recovery_sessions").doc(sessionId).set(sessionData);

    // 4. Record audit log
    await this.db.collection("audit_logs").add({
      merchantId,
      action: "RECOVERY_SESSION_CREATED",
      transactionId,
      recoverySessionId: sessionId,
      strategy,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const recoveryUrl = `/recover/${sessionId}?token=${token}`;

    return {
      success: true,
      sessionId,
      token, // Returned once to caller to construct client link
      recoveryUrl,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /**
   * Validates a recovery session token and returns customer-safe data.
   */
  async validateRecoverySession({ sessionId, token }) {
    if (!sessionId || !token) {
      return {
        valid: false,
        error: "Missing sessionId or recovery token.",
        status: "INVALID",
      };
    }

    const sessionRef = this.db.collection("recovery_sessions").doc(sessionId);
    const sessionDoc = await sessionRef.get();

    if (!sessionDoc.exists) {
      return {
        valid: false,
        error: "Recovery session not found.",
        status: "NOT_FOUND",
      };
    }

    const session = sessionDoc.data();
    const providedHash = this.hashToken(token);

    // Constant-time token hash comparison
    const storedHash = session.tokenHash || "";
    if (storedHash.length !== providedHash.length || !crypto.timingSafeEqual(Buffer.from(storedHash), Buffer.from(providedHash))) {
      return {
        valid: false,
        error: "Invalid recovery token.",
        status: "UNAUTHORIZED",
      };
    }

    if (session.status === "USED") {
      return {
        valid: false,
        error: "This recovery link has already been used.",
        status: "USED",
      };
    }

    if (session.status === "CANCELLED") {
      return {
        valid: false,
        error: "This recovery session was cancelled.",
        status: "CANCELLED",
      };
    }

    const expiresAt = session.expiresAt ? session.expiresAt.toDate() : new Date(0);
    if (new Date() > expiresAt || session.status === "EXPIRED") {
      if (session.status !== "EXPIRED") {
        await sessionRef.set({ status: "EXPIRED", updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
      }
      return {
        valid: false,
        error: "This recovery link has expired.",
        status: "EXPIRED",
      };
    }

    // Fetch transaction summary for customer display
    let amount = 0;
    let currency = "INR";
    let paymentMethod = "UPI";
    let bank = "UNKNOWN";

    if (session.transactionId) {
      const txDoc = await this.db.collection("transactions").doc(session.transactionId).get();
      if (txDoc.exists) {
        const tx = txDoc.data();
        amount = tx.amount || 0;
        currency = tx.currency || "INR";
        paymentMethod = tx.paymentMethod || "UPI";
        bank = tx.bank || "UNKNOWN";
      }
    }

    const template = this.getCustomerTemplate(session.strategy);

    // Audit validation
    await this.db.collection("audit_logs").add({
      merchantId: session.merchantId,
      action: "RECOVERY_SESSION_VALIDATED",
      transactionId: session.transactionId,
      recoverySessionId: sessionId,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      valid: true,
      sessionId,
      transactionId: session.transactionId,
      strategy: session.strategy,
      status: session.status,
      amount,
      currency,
      paymentMethod,
      bank,
      title: template.title,
      message: template.message,
      actionPrompt: template.actionPrompt,
      allowAlternate: template.allowAlternate,
      expiresAt: expiresAt.toISOString(),
    };
  }

  /**
   * Starts a customer-initiated payment retry for an active recovery session.
   */
  async startRecoveryPayment({ sessionId, token, paymentMethod = "UPI" }) {
    const validation = await this.validateRecoverySession({ sessionId, token });
    if (!validation.valid) {
      return {
        success: false,
        status: validation.status || "FAILED",
        error: validation.error,
      };
    }

    // Record audit
    await this.db.collection("audit_logs").add({
      action: "RECOVERY_PAYMENT_STARTED",
      recoverySessionId: sessionId,
      transactionId: validation.transactionId,
      paymentMethod,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      status: "PROCESSING",
      sessionId,
      transactionId: validation.transactionId,
      amount: validation.amount,
      currency: validation.currency,
      paymentMethod,
      message: "Recovery payment initiated. Waiting for payment authorization.",
    };
  }

  /**
   * Authoritative reconciliation when a recovery payment succeeds via webhook.
   */
  async reconcileRecoverySuccess({ transactionId, recoverySessionId, paymentId = null }) {
    const now = admin.firestore.FieldValue.serverTimestamp();

    // 1. Update Transaction
    if (transactionId) {
      const txRef = this.db.collection("transactions").doc(transactionId);
      await txRef.set(
        {
          status: "SUCCESS",
          recoveryOutcome: "RECOVERED",
          recoveredAt: now,
          recoverySessionId: recoverySessionId || null,
          updatedAt: now,
        },
        { merge: true }
      );
    }

    // 2. Update Recovery Session
    if (recoverySessionId) {
      const sessionRef = this.db.collection("recovery_sessions").doc(recoverySessionId);
      const sessionDoc = await sessionRef.get();
      if (sessionDoc.exists) {
        const sessionData = sessionDoc.data();
        await sessionRef.set(
          {
            status: "USED",
            usedAt: now,
            updatedAt: now,
          },
          { merge: true }
        );

        // 3. Update associated recovery attempt
        if (sessionData.recoveryAttemptId) {
          const attemptRef = this.db.collection("recovery_attempts").doc(sessionData.recoveryAttemptId);
          await attemptRef.set(
            {
              status: "COMPLETED",
              result: "RECOVERED",
              completedAt: now,
              updatedAt: now,
            },
            { merge: true }
          );
        }

        // 4. Record Audit Log
        await this.db.collection("audit_logs").add({
          merchantId: sessionData.merchantId,
          action: "RECOVERY_COMPLETED",
          transactionId,
          recoverySessionId,
          paymentId,
          createdAt: now,
        });
      }
    }
  }
}

module.exports = {
  RecoverySessionService,
  CUSTOMER_TEMPLATES,
};
