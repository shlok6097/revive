const path = require("path");
// Load environment variables for local development/emulators
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
require("dotenv").config();

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { setGlobalOptions } = require("firebase-functions/v2");
const admin = require("firebase-admin");
const { RazorpayService } = require("./services/razorpay_service");

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Global execution options
setGlobalOptions({ maxInstances: 10 });

const db = admin.firestore();
const razorpayService = new RazorpayService();

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
 * REVIVE's structured failure taxonomy, and persists into transactions collection.
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

    // 5. Mark Event as Processed (Idempotency Record)
    await processedRef.set({
      eventId: eventId,
      transactionId: normalizedTx.id,
      eventType: event.event,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 6. Record Audit Log
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
