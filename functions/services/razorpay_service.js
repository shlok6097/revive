const crypto = require("crypto");

/**
 * Backend service for Razorpay API integration, webhook verification, and error normalization.
 *
 * SECURITY INVARIANT:
 * This service runs strictly on the backend (Cloud Functions / Node.js).
 * Credentials (Key Secret) are never exposed to client applications.
 */
class RazorpayService {
  constructor(options = {}) {
    this.keyId = options.keyId || process.env.RAZORPAY_KEY_ID || process.env.razorpay_key_id;
    this.keySecret = options.keySecret || process.env.RAZORPAY_KEY_SECRET || process.env.razorpay_key_secret;
    this.webhookSecret = options.webhookSecret || process.env.RAZORPAY_WEBHOOK_SECRET || this.keySecret;
    this.baseUrl = "https://api.razorpay.com/v1";
  }

  /**
   * Generates Basic Auth header for Razorpay API.
   */
  _getAuthHeader(keyId, keySecret) {
    const kId = keyId || this.keyId;
    const kSecret = keySecret || this.keySecret;
    if (!kId || !kSecret) {
      throw new Error("Razorpay credentials are not configured.");
    }
    const token = Buffer.from(`${kId}:${kSecret}`).toString("base64");
    return `Basic ${token}`;
  }

  /**
   * Verifies that the provided or configured Razorpay credentials are valid.
   */
  async verifyCredentials(customKeyId, customKeySecret) {
    const keyId = customKeyId || this.keyId;
    const keySecret = customKeySecret || this.keySecret;

    if (!keyId || !keySecret) {
      return {
        success: false,
        error: "Missing Razorpay API Key ID or Key Secret in environment.",
      };
    }

    try {
      const response = await fetch(`${this.baseUrl}/payments?count=1`, {
        method: "GET",
        headers: {
          Authorization: this._getAuthHeader(keyId, keySecret),
          "Content-Type": "application/json",
        },
      });

      if (response.ok) {
        return {
          success: true,
          keyId: keyId,
          verifiedAt: new Date().toISOString(),
        };
      }

      const errData = await response.json().catch(() => ({}));
      return {
        success: false,
        status: response.status,
        error: errData.error?.description || `Razorpay validation failed with HTTP ${response.status}`,
      };
    } catch (err) {
      return {
        success: false,
        error: `Network error verifying Razorpay credentials: ${err.message}`,
      };
    }
  }

  /**
   * Fetches payment record from Razorpay API.
   */
  async getPayment(paymentId, customKeyId, customKeySecret) {
    const response = await fetch(`${this.baseUrl}/payments/${paymentId}`, {
      method: "GET",
      headers: {
        Authorization: this._getAuthHeader(customKeyId, customKeySecret),
        "Content-Type": "application/json",
      },
    });

    if (!response.ok) {
      const err = await response.json().catch(() => ({}));
      throw new Error(err.error?.description || `Failed to fetch payment ${paymentId}`);
    }

    return response.json();
  }

  /**
   * Validates the cryptographic signature of an incoming Razorpay webhook payload.
   *
   * @param {string|Buffer} rawBody The raw payload string/buffer.
   * @param {string} signature The value of the 'x-razorpay-signature' header.
   * @param {string} [customSecret] Optional webhook secret (defaults to configured secret).
   * @returns {boolean} True if signature matches.
   */
  validateWebhookSignature(rawBody, signature, customSecret) {
    const secret = customSecret || this.webhookSecret;
    if (!rawBody || !signature || !secret) {
      return false;
    }

    try {
      const expectedSignature = crypto
        .createHmac("sha256", secret)
        .update(typeof rawBody === "string" ? rawBody : rawBody.toString("utf8"))
        .digest("hex");

      const expectedBuffer = Buffer.from(expectedSignature, "utf8");
      const signatureBuffer = Buffer.from(signature, "utf8");

      if (expectedBuffer.length !== signatureBuffer.length) {
        return false;
      }

      return crypto.timingSafeEqual(expectedBuffer, signatureBuffer);
    } catch (e) {
      return false;
    }
  }

  /**
   * Normalizes a Razorpay webhook event into REVIVE's standard TransactionModel.
   *
   * Preserves Razorpay structured error taxonomy:
   * - errorCode (error_code)
   * - errorReason (error_description)
   * - errorSource (error_source)
   * - errorStep (error_step)
   *
   * @param {object} event The parsed Razorpay webhook payload.
   * @param {string} [defaultMerchantId] Fallback merchant ID if not present in payload.
   * @returns {object} Normalized transaction entity.
   */
  normalizePaymentEvent(event, defaultMerchantId = null) {
    const payload = event.payload || {};
    const entity = payload.payment?.entity || payload.order?.entity || {};

    // Extract Merchant ID from notes or default
    const merchantId =
      entity.notes?.merchantId ||
      entity.notes?.merchant_id ||
      event.account_id ||
      defaultMerchantId ||
      "unassigned_merchant";

    // Map status to REVIVE taxonomy
    let status = "PENDING";
    const rawStatus = (entity.status || "").toLowerCase();
    const eventType = (event.event || "").toLowerCase();

    if (rawStatus === "captured" || rawStatus === "authorized" || eventType === "payment.captured" || eventType === "payment.authorized") {
      status = "SUCCESS";
    } else if (rawStatus === "failed" || eventType === "payment.failed") {
      status = "FAILED";
    } else if (rawStatus === "refunded" || eventType.includes("refund")) {
      status = "REFUNDED";
    }

    // Convert amount from paise to rupees
    const rawAmount = typeof entity.amount === "number" ? entity.amount / 100 : 0.0;

    return {
      id: entity.id || event.event_id || `tx_${Date.now()}`,
      merchantId: merchantId,
      amount: rawAmount,
      currency: entity.currency || "INR",
      status: status,
      paymentMethod: (entity.method || "UPI").toUpperCase(),
      bank: (entity.bank || entity.wallet || entity.vpa || "UNKNOWN").toUpperCase(),
      errorCode: entity.error_code || null,
      errorReason: entity.error_description || entity.error_reason || null,
      errorSource: entity.error_source ? entity.error_source.toUpperCase() : null,
      errorStep: entity.error_step ? entity.error_step.toUpperCase() : null,
      customerId: entity.customer_id || entity.contact || entity.email || null,
      rawEvent: event.event || null,
      createdAt: entity.created_at ? new Date(entity.created_at * 1000) : new Date(),
      updatedAt: new Date(),
    };
  }
}

module.exports = {
  RazorpayService,
};
