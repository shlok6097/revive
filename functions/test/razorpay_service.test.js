const test = require("node:test");
const assert = require("node:assert");
const crypto = require("crypto");
const { RazorpayService } = require("../services/razorpay_service");

test("RazorpayService - Webhook signature verification", async (t) => {
  const secret = "test_webhook_secret_key_123";
  const service = new RazorpayService({ webhookSecret: secret });

  const rawPayload = JSON.stringify({
    event: "payment.failed",
    account_id: "acc_test_merchant_99",
    payload: {
      payment: {
        entity: {
          id: "pay_test_001",
          amount: 499900,
          currency: "INR",
          status: "failed",
          method: "netbanking",
          bank: "SBI",
          error_code: "GATEWAY_TIMEOUT",
          error_description: "Bank server timed out during MPIN check",
          error_source: "bank_gateway",
          error_step: "otp_verification",
        },
      },
    },
  });

  const validSignature = crypto
    .createHmac("sha256", secret)
    .update(rawPayload)
    .digest("hex");

  await t.test("Valid signature returns true", () => {
    const isValid = service.validateWebhookSignature(rawPayload, validSignature);
    assert.strictEqual(isValid, true);
  });

  await t.test("Invalid signature returns false", () => {
    const isInvalid = service.validateWebhookSignature(
      rawPayload,
      "invalid_signature_hex"
    );
    assert.strictEqual(isInvalid, false);
  });

  await t.test("Tampered payload returns false", () => {
    const tamperedPayload = rawPayload + " ";
    const isInvalid = service.validateWebhookSignature(
      tamperedPayload,
      validSignature
    );
    assert.strictEqual(isInvalid, false);
  });
});

test("RazorpayService - Error normalization and structured taxonomy", async (t) => {
  const service = new RazorpayService();

  const failedEvent = {
    event: "payment.failed",
    account_id: "acc_test_merchant_99",
    payload: {
      payment: {
        entity: {
          id: "pay_test_failed_889",
          amount: 250000,
          currency: "INR",
          status: "failed",
          method: "upi",
          bank: "HDFC",
          error_code: "BAD_REQUEST_GATEWAY_TIMEOUT",
          error_description: "PSP timed out while contacting issuing bank",
          error_source: "issuer_network",
          error_step: "payment_authorization",
          customer_id: "cust_9021",
          notes: {
            merchantId: "merchant_uid_777",
          },
          created_at: 1725400000,
        },
      },
    },
  };

  const normalized = service.normalizePaymentEvent(failedEvent);

  assert.strictEqual(normalized.id, "pay_test_failed_889");
  assert.strictEqual(normalized.merchantId, "merchant_uid_777");
  assert.strictEqual(normalized.amount, 2500.0); // Converted from paise
  assert.strictEqual(normalized.currency, "INR");
  assert.strictEqual(normalized.status, "FAILED");
  assert.strictEqual(normalized.paymentMethod, "UPI");
  assert.strictEqual(normalized.bank, "HDFC");
  assert.strictEqual(normalized.errorCode, "BAD_REQUEST_GATEWAY_TIMEOUT");
  assert.strictEqual(
    normalized.errorReason,
    "PSP timed out while contacting issuing bank"
  );
  assert.strictEqual(normalized.errorSource, "ISSUER_NETWORK");
  assert.strictEqual(normalized.errorStep, "PAYMENT_AUTHORIZATION");
  assert.strictEqual(normalized.customerId, "cust_9021");
});

test("RazorpayService - Successful payment normalization", async (t) => {
  const service = new RazorpayService();

  const successEvent = {
    event: "payment.captured",
    payload: {
      payment: {
        entity: {
          id: "pay_test_success_123",
          amount: 150000,
          currency: "INR",
          status: "captured",
          method: "card",
          bank: "ICICI",
          notes: {
            merchantId: "merchant_uid_777",
          },
        },
      },
    },
  };

  const normalized = service.normalizePaymentEvent(successEvent);

  assert.strictEqual(normalized.id, "pay_test_success_123");
  assert.strictEqual(normalized.amount, 1500.0);
  assert.strictEqual(normalized.status, "SUCCESS");
  assert.strictEqual(normalized.errorCode, null);
  assert.strictEqual(normalized.errorReason, null);
});
