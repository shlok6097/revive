const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const { RecoverySessionService, CUSTOMER_TEMPLATES } = require("../services/recovery_session_service");

describe("RecoverySessionService - Cryptographic Security & Session Lifecycle", () => {
  // Mock In-Memory Firestore database
  const createMockDb = () => {
    const collections = {
      transactions: new Map(),
      recovery_sessions: new Map(),
      recovery_attempts: new Map(),
      audit_logs: [],
    };

    return {
      collections,
      collection: (name) => ({
        doc: (id) => ({
          get: async () => ({
            exists: collections[name]?.has(id) || false,
            data: () => collections[name]?.get(id),
          }),
          set: async (data, options) => {
            if (!collections[name]) collections[name] = new Map();
            if (options && options.merge && collections[name].has(id)) {
              collections[name].set(id, { ...collections[name].get(id), ...data });
            } else {
              collections[name].set(id, data);
            }
          },
        }),
        add: async (data) => {
          if (!collections[name]) collections[name] = [];
          collections[name].push(data);
          return { id: `auto_${Date.now()}` };
        },
      }),
    };
  };

  test("Token hashing produces valid deterministic SHA-256 hex string", () => {
    const service = new RecoverySessionService();
    const token = "a".repeat(64);
    const hash = service.hashToken(token);

    assert.equal(typeof hash, "string");
    assert.equal(hash.length, 64);
    assert.equal(hash, service.hashToken(token));
  });

  test("Creates recovery session storing only tokenHash and creates audit log", async () => {
    const mockDb = createMockDb();
    mockDb.collections.transactions.set("tx_test_01", {
      merchantId: "merchant_alpha",
      amount: 1499.0,
      currency: "INR",
      paymentMethod: "UPI",
      bank: "HDFC",
    });

    const service = new RecoverySessionService({ firestore: mockDb });
    const result = await service.createRecoverySession({
      merchantId: "merchant_alpha",
      transactionId: "tx_test_01",
      strategy: "RETRY",
    });

    assert.equal(result.success, true);
    assert.ok(result.sessionId.startsWith("ses_"));
    assert.ok(result.token);
    assert.ok(result.recoveryUrl.includes(result.sessionId));

    // Verify persisted session in DB
    const stored = mockDb.collections.recovery_sessions.get(result.sessionId);
    assert.ok(stored);
    assert.equal(stored.merchantId, "merchant_alpha");
    assert.equal(stored.status, "ACTIVE");
    assert.equal(stored.tokenHash, service.hashToken(result.token));
    assert.equal(stored.token, undefined, "Raw token must NEVER be stored in database");

    // Verify audit log
    const audit = mockDb.collections.audit_logs.find((a) => a.action === "RECOVERY_SESSION_CREATED");
    assert.ok(audit);
    assert.equal(audit.recoverySessionId, result.sessionId);
  });

  test("Enforces merchant isolation when creating recovery session", async () => {
    const mockDb = createMockDb();
    mockDb.collections.transactions.set("tx_cross_tenant", {
      merchantId: "merchant_owner",
      amount: 2500,
    });

    const service = new RecoverySessionService({ firestore: mockDb });
    await assert.rejects(
      async () => {
        await service.createRecoverySession({
          merchantId: "merchant_intruder",
          transactionId: "tx_cross_tenant",
        });
      },
      /not authorized/
    );
  });

  test("Validates active session and returns deterministic customer-safe template", async () => {
    const mockDb = createMockDb();
    mockDb.collections.transactions.set("tx_test_02", {
      merchantId: "merchant_alpha",
      amount: 3299.0,
      currency: "INR",
      paymentMethod: "UPI",
      bank: "ICICI",
    });

    const service = new RecoverySessionService({ firestore: mockDb });
    const created = await service.createRecoverySession({
      merchantId: "merchant_alpha",
      transactionId: "tx_test_02",
      strategy: "ALTERNATIVE_METHOD",
    });

    const validation = await service.validateRecoverySession({
      sessionId: created.sessionId,
      token: created.token,
    });

    assert.equal(validation.valid, true);
    assert.equal(validation.amount, 3299.0);
    assert.equal(validation.currency, "INR");
    assert.equal(validation.title, CUSTOMER_TEMPLATES.ALTERNATIVE_METHOD.title);
    assert.equal(validation.message, CUSTOMER_TEMPLATES.ALTERNATIVE_METHOD.message);
    assert.equal(validation.actionPrompt, "Use Another Method");
  });

  test("Rejects validation with invalid or tampered token", async () => {
    const mockDb = createMockDb();
    mockDb.collections.transactions.set("tx_test_03", {
      merchantId: "merchant_alpha",
      amount: 500,
    });

    const service = new RecoverySessionService({ firestore: mockDb });
    const created = await service.createRecoverySession({
      merchantId: "merchant_alpha",
      transactionId: "tx_test_03",
      strategy: "RETRY",
    });

    const tampered = "b".repeat(64);
    const validation = await service.validateRecoverySession({
      sessionId: created.sessionId,
      token: tampered,
    });

    assert.equal(validation.valid, false);
    assert.equal(validation.status, "UNAUTHORIZED");
  });

  test("Rejects validation for expired session", async () => {
    const mockDb = createMockDb();
    const service = new RecoverySessionService({ firestore: mockDb });
    const token = service.generateToken();
    const sessionId = "ses_expired_01";

    mockDb.collections.recovery_sessions.set(sessionId, {
      merchantId: "merchant_alpha",
      transactionId: "tx_01",
      tokenHash: service.hashToken(token),
      status: "ACTIVE",
      expiresAt: { toDate: () => new Date(Date.now() - 10000) }, // in the past
    });

    const validation = await service.validateRecoverySession({
      sessionId,
      token,
    });

    assert.equal(validation.valid, false);
    assert.equal(validation.status, "EXPIRED");
  });

  test("Rejects validation for already USED session", async () => {
    const mockDb = createMockDb();
    const service = new RecoverySessionService({ firestore: mockDb });
    const token = service.generateToken();
    const sessionId = "ses_used_01";

    mockDb.collections.recovery_sessions.set(sessionId, {
      merchantId: "merchant_alpha",
      transactionId: "tx_01",
      tokenHash: service.hashToken(token),
      status: "USED",
      expiresAt: { toDate: () => new Date(Date.now() + 600000) },
    });

    const validation = await service.validateRecoverySession({
      sessionId,
      token,
    });

    assert.equal(validation.valid, false);
    assert.equal(validation.status, "USED");
  });

  test("Reconciles webhook recovery: updates transaction to SUCCESS, session to USED, attempt to COMPLETED", async () => {
    const mockDb = createMockDb();
    const service = new RecoverySessionService({ firestore: mockDb });

    mockDb.collections.transactions.set("tx_rec_01", {
      merchantId: "merchant_alpha",
      status: "FAILED",
    });
    mockDb.collections.recovery_sessions.set("ses_rec_01", {
      merchantId: "merchant_alpha",
      transactionId: "tx_rec_01",
      recoveryAttemptId: "att_rec_01",
      status: "ACTIVE",
    });
    mockDb.collections.recovery_attempts.set("att_rec_01", {
      merchantId: "merchant_alpha",
      status: "EXECUTING",
    });

    await service.reconcileRecoverySuccess({
      transactionId: "tx_rec_01",
      recoverySessionId: "ses_rec_01",
      paymentId: "pay_live_test_123",
    });

    const tx = mockDb.collections.transactions.get("tx_rec_01");
    assert.equal(tx.status, "SUCCESS");
    assert.equal(tx.recoveryOutcome, "RECOVERED");
    assert.equal(tx.recoverySessionId, "ses_rec_01");

    const session = mockDb.collections.recovery_sessions.get("ses_rec_01");
    assert.equal(session.status, "USED");

    const attempt = mockDb.collections.recovery_attempts.get("att_rec_01");
    assert.equal(attempt.status, "COMPLETED");
    assert.equal(attempt.result, "RECOVERED");

    const audit = mockDb.collections.audit_logs.find((a) => a.action === "RECOVERY_COMPLETED");
    assert.ok(audit);
    assert.equal(audit.paymentId, "pay_live_test_123");
  });
});
