const path = require("path");
// Load environment variables for local development/emulators
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
require("dotenv").config();

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const { RazorpayService } = require("./services/razorpay_service");
const { BackendRecoveryExecutor } = require("./services/recovery_executor");
const { RecoverySessionService } = require("./services/recovery_session_service");

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Global execution options
setGlobalOptions({ maxInstances: 10 });

const db = admin.firestore();
const razorpayService = new RazorpayService();
const recoveryExecutor = new BackendRecoveryExecutor({ firestore: db, razorpayService });
const recoverySessionService = new RecoverySessionService({ firestore: db });

/**
 * Callable Function: Connect Razorpay
 *
 * Verifies Razorpay credentials and links the merchant account.
 * Authentication is strictly enforced using request.auth.uid.
 */
exports.connectRazorpay = onCall(async (request) => {
  // 1. Verify authentication
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to perform Razorpay connection."
    );
  }

  const merchantId = request.auth.uid;
  const customKeyId = request.data?.keyId;
  const customKeySecret = request.data?.keySecret;

  // 2. Validate credentials with Razorpay API
  const verification = await razorpayService.verifyCredentials(
    customKeyId,
    customKeySecret
  );

  if (!verification.success) {
    throw new HttpsError(
      "invalid-argument",
      verification.error || "Failed to verify Razorpay credentials."
    );
  }

  const accountId = verification.keyId;

  // 3. Persist connection metadata in merchants/{merchantId}
  // SECURITY INVARIANT: Secret key is never saved to Firestore.
  const merchantRef = db.collection("merchants").doc(merchantId);
  await merchantRef.set(
    {
      razorpayConnected: true,
      razorpayAccountId: accountId,
      razorpayConnectedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // 4. Record audit log
  await db.collection("audit_logs").add({
    merchantId: merchantId,
    action: "RAZORPAY_CONNECTED",
    entityType: "MERCHANT",
    entityId: merchantId,
    metadata: {
      accountId: accountId,
      verifiedAt: verification.verifiedAt,
    },
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    accountId: accountId,
    connectedAt: new Date().toISOString(),
  };
});

/**
 * Callable Function: Disconnect Razorpay
 *
 * Unlinks the Razorpay account connection from the merchant profile.
 */
exports.disconnectRazorpay = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to disconnect Razorpay."
    );
  }

  const merchantId = request.auth.uid;
  const merchantRef = db.collection("merchants").doc(merchantId);

  await merchantRef.set(
    {
      razorpayConnected: false,
      razorpayConnectedAt: null,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // Record audit log
  await db.collection("audit_logs").add({
    merchantId: merchantId,
    action: "RAZORPAY_DISCONNECTED",
    entityType: "MERCHANT",
    entityId: merchantId,
    metadata: {},
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    disconnectedAt: new Date().toISOString(),
  };
});

/**
 * Callable Function: Get Razorpay Connection Status
 */
exports.getRazorpayConnection = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to query Razorpay status."
    );
  }

  const merchantId = request.auth.uid;
  const doc = await db.collection("merchants").doc(merchantId).get();

  if (!doc.exists) {
    return {
      connected: false,
      accountId: null,
      connectedAt: null,
    };
  }

  const data = doc.data();
  return {
    connected: data.razorpayConnected === true,
    accountId: data.razorpayAccountId || null,
    connectedAt: data.razorpayConnectedAt
      ? data.razorpayConnectedAt.toDate().toISOString()
      : null,
  };
});

/**
 * HTTP Webhook: Ingest Razorpay Payment Events
 *
 * Verifies HMAC SHA256 signature, enforces idempotency, normalizes event into
 * REVIVE's structured failure taxonomy, reconciles recovery outcomes, and persists.
 */
exports.razorpayWebhook = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  const signature = req.headers["x-razorpay-signature"];
  const rawBody = req.rawBody || JSON.stringify(req.body);

  // 1. Verify Webhook Signature
  const isValid = razorpayService.validateWebhookSignature(rawBody, signature);
  if (!isValid) {
    console.error("Rejected unverified Razorpay webhook signature.");
    res.status(400).json({ error: "Invalid webhook signature" });
    return;
  }

  const event = req.body || {};
  const eventId =
    event.event_id ||
    req.headers["x-razorpay-event-id"] ||
    (event.payload?.payment?.entity?.id
      ? `${event.payload.payment.entity.id}_${event.event}`
      : `event_${Date.now()}`);

  try {
    // 2. Idempotency Check: Prevent duplicate event processing
    const processedRef = db.collection("processed_events").doc(eventId);
    const processedDoc = await processedRef.get();

    if (processedDoc.exists) {
      console.log(`Duplicate webhook event ${eventId} ignored.`);
      res.status(200).json({ status: "already_processed", eventId });
      return;
    }

    // 3. Normalize Payment Event into REVIVE's Transaction Model
    const normalizedTx = razorpayService.normalizePaymentEvent(event);

    // 4. Persist Transaction to Firestore
    const txRef = db.collection("transactions").doc(normalizedTx.id);
    await txRef.set(
      {
        merchantId: normalizedTx.merchantId,
        amount: normalizedTx.amount,
        currency: normalizedTx.currency,
        status: normalizedTx.status,
        paymentMethod: normalizedTx.paymentMethod,
        bank: normalizedTx.bank,
        errorCode: normalizedTx.errorCode,
        errorReason: normalizedTx.errorReason,
        errorSource: normalizedTx.errorSource,
        errorStep: normalizedTx.errorStep,
        customerId: normalizedTx.customerId,
        createdAt: admin.firestore.Timestamp.fromDate(normalizedTx.createdAt),
        updatedAt: admin.firestore.Timestamp.fromDate(normalizedTx.updatedAt),
      },
      { merge: true }
    );

    // 5. If Payment Succeeded, reconcile recovery outcome if linked
    if (normalizedTx.status === "SUCCESS") {
      const recoverySessionId =
        event.payload?.payment?.entity?.notes?.recoverySessionId ||
        event.payload?.payment?.entity?.notes?.recovery_session_id;

      await recoverySessionService.reconcileRecoverySuccess({
        transactionId: normalizedTx.id,
        recoverySessionId: recoverySessionId || null,
        paymentId: event.payload?.payment?.entity?.id || null,
      });
    }

    // 6. Mark Event as Processed (Idempotency Record)
    await processedRef.set({
      eventId: eventId,
      transactionId: normalizedTx.id,
      eventType: event.event,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 7. Record Audit Log
    await db.collection("audit_logs").add({
      merchantId: normalizedTx.merchantId,
      action: "WEBHOOK_PAYMENT_INGESTED",
      entityType: "TRANSACTION",
      entityId: normalizedTx.id,
      metadata: {
        status: normalizedTx.status,
        amount: normalizedTx.amount,
        errorCode: normalizedTx.errorCode,
      },
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(200).json({
      status: "success",
      transactionId: normalizedTx.id,
      eventId: eventId,
    });
  } catch (error) {
    console.error("Error processing Razorpay webhook:", error);
    res.status(500).json({ error: "Internal server error processing event" });
  }
});

/**
 * Callable Function: Execute Recovery (Phase 7)
 */
exports.executeRecovery = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to execute recovery attempt."
    );
  }

  const merchantId = request.auth.uid;
  const transactionId = request.data?.transactionId;
  const recoveryAttemptId = request.data?.recoveryAttemptId;
  const simulation = request.data?.simulation !== false; // default true for safety
  const confirmed = request.data?.confirmed === true;

  if (!transactionId || !recoveryAttemptId) {
    throw new HttpsError(
      "invalid-argument",
      "Both 'transactionId' and 'recoveryAttemptId' are required."
    );
  }

  try {
    const result = await recoveryExecutor.executeRecovery({
      merchantId,
      transactionId,
      recoveryAttemptId,
      simulation,
      confirmed,
    });

    return result;
  } catch (error) {
    console.error("Error in executeRecovery:", error);
    throw new HttpsError("internal", error.message || "Failed to execute recovery.");
  }
});

/**
 * Callable Function: Create Recovery Session (Phase 8)
 *
 * Generates a cryptographically secure, expiring recovery session.
 * Stores only the SHA-256 hash of the recovery token.
 */
exports.createRecoverySession = onCall(async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Authentication required to create recovery session."
    );
  }

  const merchantId = request.auth.uid;
  const transactionId = request.data?.transactionId;
  const recoveryAttemptId = request.data?.recoveryAttemptId;
  const customerId = request.data?.customerId;
  const strategy = request.data?.strategy || "RETRY";

  if (!transactionId) {
    throw new HttpsError("invalid-argument", "Missing required 'transactionId'.");
  }

  try {
    const session = await recoverySessionService.createRecoverySession({
      merchantId,
      transactionId,
      recoveryAttemptId,
      customerId,
      strategy,
    });

    return session;
  } catch (error) {
    console.error("Error creating recovery session:", error);
    throw new HttpsError("internal", error.message || "Failed to create recovery session.");
  }
});

/**
 * Callable Function: Validate Recovery Session (Phase 8)
 *
 * Customer-facing validation. Validates token hash, expiry, and returns customer-safe data.
 */
exports.validateRecoverySession = onCall(async (request) => {
  const sessionId = request.data?.sessionId;
  const token = request.data?.token;

  if (!sessionId || !token) {
    throw new HttpsError("invalid-argument", "Both 'sessionId' and 'token' are required.");
  }

  try {
    const validation = await recoverySessionService.validateRecoverySession({
      sessionId,
      token,
    });

    return validation;
  } catch (error) {
    console.error("Error validating recovery session:", error);
    throw new HttpsError("internal", error.message || "Failed to validate recovery session.");
  }
});

/**
 * Callable Function: Start Recovery Payment (Phase 8)
 *
 * Customer-initiated payment retry under backend security validation.
 */
exports.startRecoveryPayment = onCall(async (request) => {
  const sessionId = request.data?.sessionId;
  const token = request.data?.token;
  const paymentMethod = request.data?.paymentMethod || "UPI";

  if (!sessionId || !token) {
    throw new HttpsError("invalid-argument", "Both 'sessionId' and 'token' are required.");
  }

  try {
    const paymentResult = await recoverySessionService.startRecoveryPayment({
      sessionId,
      token,
      paymentMethod,
    });

    return paymentResult;
  } catch (error) {
    console.error("Error starting recovery payment:", error);
    throw new HttpsError("internal", error.message || "Failed to start recovery payment.");
  }
});
