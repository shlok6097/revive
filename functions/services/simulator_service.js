const crypto = require("crypto");
const admin = require("firebase-admin");

/**
 * Predefined failure scenario presets for deterministic simulation.
 */
const SCENARIO_PRESETS = {
  BANK_DECLINE: {
    id: "BANK_DECLINE",
    title: "Bank Decline",
    amount: 1250.0,
    currency: "INR",
    paymentMethod: "UPI",
    bank: "HDFC",
    errorCode: "BAD_REQUEST_ERROR",
    errorReason: "Payment declined by bank",
    errorSource: "bank",
    errorStep: "authorization",
  },
  NETWORK_ERROR: {
    id: "NETWORK_ERROR",
    title: "Network Timeout",
    amount: 850.0,
    currency: "INR",
    paymentMethod: "UPI",
    bank: "ICICI",
    errorCode: "GATEWAY_TIMEOUT",
    errorReason: "Gateway timeout contacting issuing bank",
    errorSource: "gateway",
    errorStep: "payment_authorization",
  },
  INSUFFICIENT_FUNDS: {
    id: "INSUFFICIENT_FUNDS",
    title: "Insufficient Funds",
    amount: 3200.0,
    currency: "INR",
    paymentMethod: "UPI",
    bank: "SBI",
    errorCode: "INSUFFICIENT_FUNDS",
    errorReason: "Customer account has insufficient funds",
    errorSource: "bank",
    errorStep: "debit_attempt",
  },
  INVALID_DETAILS: {
    id: "INVALID_DETAILS",
    title: "Invalid Card Details",
    amount: 2100.0,
    currency: "INR",
    paymentMethod: "CARD",
    bank: "AXIS",
    errorCode: "BAD_REQUEST_CARD_INVALID",
    errorReason: "Invalid card CVV or expiry",
    errorSource: "customer_app",
    errorStep: "card_entry",
  },
  AUTHENTICATION_FAILURE: {
    id: "AUTHENTICATION_FAILURE",
    title: "2FA Auth Failure",
    amount: 1750.0,
    currency: "INR",
    paymentMethod: "NETBANKING",
    bank: "KOTAK",
    errorCode: "AUTH_FAILED_OTP",
    errorReason: "2FA authentication failed or expired",
    errorSource: "authentication_server",
    errorStep: "otp_verification",
  },
  FRAUD_RISK: {
    id: "FRAUD_RISK",
    title: "Fraud Risk Filter",
    amount: 45000.0,
    currency: "INR",
    paymentMethod: "CARD",
    bank: "HDFC",
    errorCode: "RISK_SUSPECTED_FRAUD",
    errorReason: "Transaction blocked by risk safety filter",
    errorSource: "risk_engine",
    errorStep: "risk_scoring",
  },
  UNKNOWN: {
    id: "UNKNOWN",
    title: "Unknown Anomaly",
    amount: 999.0,
    currency: "INR",
    paymentMethod: "UPI",
    bank: "UNKNOWN",
    errorCode: "UNKNOWN_DISRUPTION",
    errorReason: "Undocumented gateway telemetry anomaly",
    errorSource: "unknown",
    errorStep: "processing",
  },
};

/**
 * Backend service managing end-to-end payment failure simulations and safe reconciliation.
 */
class SimulatorService {
  constructor({ firestore = null } = {}) {
    this.firestore = firestore || (admin.apps.length ? admin.firestore() : null);
  }

  get db() {
    if (!this.firestore) {
      if (!admin.apps.length) admin.initializeApp();
      this.firestore = admin.firestore();
    }
    return this.firestore;
  }

  /**
   * Generates a deterministic simulated failed transaction and writes audit events.
   */
  async runPaymentSimulation({ merchantId, scenarioId = "BANK_DECLINE", customAmount = null }) {
    if (!merchantId) {
      throw new Error("Authentication required. Merchant ID missing.");
    }

    const scenarioKey = (scenarioId || "BANK_DECLINE").toUpperCase();
    const scenario = SCENARIO_PRESETS[scenarioKey] || SCENARIO_PRESETS.BANK_DECLINE;

    const transactionId = `tx_sim_${Date.now()}_${crypto.randomBytes(3).toString("hex")}`;
    const now = new Date();

    const transactionData = {
      merchantId,
      amount: customAmount ? Number(customAmount) : scenario.amount,
      currency: scenario.currency,
      status: "FAILED",
      paymentMethod: scenario.paymentMethod,
      bank: scenario.bank,
      errorCode: scenario.errorCode,
      errorReason: scenario.errorReason,
      errorSource: scenario.errorSource,
      errorStep: scenario.errorStep,
      customerId: `cust_sim_${merchantId.substring(0, 6)}`,
      simulated: true,
      recoveryOutcome: null,
      recoveredAt: null,
      recoverySessionId: null,
      createdAt: admin.firestore.Timestamp.fromDate(now),
      updatedAt: admin.firestore.Timestamp.fromDate(now),
    };

    // Save transaction
    await this.db.collection("transactions").doc(transactionId).set(transactionData);

    // Record audit events
    await this.db.collection("audit_logs").add({
      merchantId,
      action: "SIMULATION_STARTED",
      transactionId,
      scenarioId: scenario.id,
      simulated: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    await this.db.collection("audit_logs").add({
      merchantId,
      action: "SIMULATION_TRANSACTION_CREATED",
      transactionId,
      amount: transactionData.amount,
      errorCode: scenario.errorCode,
      simulated: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      transactionId,
      transaction: {
        id: transactionId,
        ...transactionData,
        createdAt: now.toISOString(),
        updatedAt: now.toISOString(),
      },
      scenario,
      simulated: true,
    };
  }

  /**
   * Safe backend reconciliation path for simulated customer payment completion.
   * SECURITY INVARIANT:
   * Only transactions with simulated == true may be reconciled through this demo flow.
   */
  async simulateCustomerPaymentSuccess({ sessionId, transactionId }) {
    if (!sessionId || !transactionId) {
      throw new Error("Both sessionId and transactionId are required for simulation reconciliation.");
    }

    // 1. Verify transaction exists and is marked simulated: true
    const txRef = this.db.collection("transactions").doc(transactionId);
    const txDoc = await txRef.get();

    if (!txDoc.exists) {
      throw new Error("Transaction not found.");
    }

    const txData = txDoc.data();
    if (txData.simulated !== true) {
      throw new Error("Security Violation: Simulated payment completion is strictly prohibited for live production transactions.");
    }

    const now = admin.firestore.FieldValue.serverTimestamp();

    // 2. Mark Transaction as RECOVERED
    await txRef.set(
      {
        status: "SUCCESS",
        recoveryOutcome: "RECOVERED",
        recoveredAt: now,
        recoverySessionId: sessionId,
        updatedAt: now,
      },
      { merge: true }
    );

    // 3. Mark Recovery Session as USED
    const sessionRef = this.db.collection("recovery_sessions").doc(sessionId);
    const sessionDoc = await sessionRef.get();
    let recoveryAttemptId = null;
    let merchantId = txData.merchantId;

    if (sessionDoc.exists) {
      const sessionData = sessionDoc.data();
      recoveryAttemptId = sessionData.recoveryAttemptId || null;
      merchantId = sessionData.merchantId || merchantId;

      await sessionRef.set(
        {
          status: "USED",
          usedAt: now,
          updatedAt: now,
        },
        { merge: true }
      );
    }

    // 4. Mark Recovery Attempt as COMPLETED
    if (recoveryAttemptId) {
      const attemptRef = this.db.collection("recovery_attempts").doc(recoveryAttemptId);
      await attemptRef.set(
        {
          status: "COMPLETED",
          result: "SIMULATED_RECOVERY_SUCCESS",
          completedAt: now,
          updatedAt: now,
        },
        { merge: true }
      );
    }

    // 5. Write audit logs
    await this.db.collection("audit_logs").add({
      merchantId,
      action: "SIMULATION_PAYMENT_COMPLETED",
      transactionId,
      recoverySessionId: sessionId,
      simulated: true,
      createdAt: now,
    });

    await this.db.collection("audit_logs").add({
      merchantId,
      action: "SIMULATION_RECONCILED",
      transactionId,
      recoverySessionId: sessionId,
      simulated: true,
      createdAt: now,
    });

    return {
      success: true,
      status: "RECOVERED",
      transactionId,
      recoverySessionId: sessionId,
      simulated: true,
      message: "Simulated recovery reconciled successfully.",
    };
  }
}

module.exports = {
  SimulatorService,
  SCENARIO_PRESETS,
};
