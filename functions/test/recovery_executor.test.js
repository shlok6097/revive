const { describe, it } = require("node:test");
const assert = require("node:assert");
const { BackendRecoveryExecutor } = require("../services/recovery_executor");

/**
 * Mock Firestore database for testing backend recovery executor logic in isolation.
 */
function createMockDb(initialDocs = {}) {
  const store = { ...initialDocs };
  const auditLogs = [];

  const getDoc = (collection, id) => {
    const key = `${collection}/${id}`;
    return {
      exists: key in store,
      id: id,
      data: () => store[key],
    };
  };

  const setDoc = (collection, id, data, options = {}) => {
    const key = `${collection}/${id}`;
    if (options.merge && store[key]) {
      store[key] = { ...store[key], ...data };
    } else {
      store[key] = data;
    }
  };

  return {
    _store: store,
    _auditLogs: auditLogs,
    collection: (colName) => ({
      doc: (docId) => ({
        get: async () => getDoc(colName, docId),
        set: async (data, opts) => setDoc(colName, docId, data, opts),
      }),
      where: (field, op, val) => ({
        where: () => ({
          get: async () => ({ docs: [] }),
        }),
        get: async () => {
          const results = Object.entries(store)
            .filter(([k, v]) => k.startsWith(`${colName}/`) && v[field] === val)
            .map(([k, v]) => ({ id: k.split("/")[1], data: () => v }));
          return { docs: results };
        },
      }),
      add: async (data) => {
        auditLogs.push(data);
        return { id: `log_${Date.now()}` };
      },
    }),
  };
}

describe("BackendRecoveryExecutor - Execution Guard & Strategy Rules", () => {
  const executor = new BackendRecoveryExecutor({ firestore: createMockDb() });

  it("Blocks execution if merchantId does not match recoveryAttempt", () => {
    const guard = executor.validateExecutionGuard({
      recoveryAttempt: { merchantId: "merchant_alpha", status: "APPROVED", strategy: "RETRY" },
      transaction: { merchantId: "merchant_alpha" },
      merchantPolicy: { maxAutomaticRetries: 1, autonomyMode: "MANUAL" },
      merchantId: "merchant_intruder",
      simulation: true,
    });

    assert.strictEqual(guard.allowed, false);
    assert.strictEqual(guard.status, "BLOCKED");
  });

  it("Rejects non-executable strategies such as ALTERNATIVE_METHOD and ESCALATE", () => {
    const guard = executor.validateExecutionGuard({
      recoveryAttempt: { merchantId: "merchant_alpha", status: "APPROVED", strategy: "ALTERNATIVE_METHOD" },
      transaction: { merchantId: "merchant_alpha" },
      merchantPolicy: { maxAutomaticRetries: 1, autonomyMode: "MANUAL" },
      merchantId: "merchant_alpha",
      simulation: true,
    });

    assert.strictEqual(guard.allowed, false);
    assert.strictEqual(guard.status, "NOT_EXECUTABLE");
  });

  it("Rejects invalid recovery attempt statuses like FAILED or COMPLETED", () => {
    const guard = executor.validateExecutionGuard({
      recoveryAttempt: { merchantId: "merchant_alpha", status: "FAILED", strategy: "RETRY" },
      transaction: { merchantId: "merchant_alpha" },
      merchantPolicy: { maxAutomaticRetries: 1, autonomyMode: "MANUAL" },
      merchantId: "merchant_alpha",
      simulation: true,
    });

    assert.strictEqual(guard.allowed, false);
    assert.strictEqual(guard.status, "BLOCKED");
  });

  it("Blocks automated execution when risk rule flags FRAUD_RISK", () => {
    const guard = executor.validateExecutionGuard({
      recoveryAttempt: { merchantId: "merchant_alpha", status: "APPROVED", strategy: "RETRY" },
      transaction: { merchantId: "merchant_alpha", failureCategory: "FRAUD_RISK" },
      merchantPolicy: { maxAutomaticRetries: 1, autonomyMode: "AUTONOMOUS", automaticRetryEnabled: true },
      merchantId: "merchant_alpha",
      simulation: true,
    });

    assert.strictEqual(guard.allowed, false);
    assert.strictEqual(guard.status, "BLOCKED");
  });

  it("Enforces retry limits when previous attempts exceed maxAutomaticRetries", () => {
    const guard = executor.validateExecutionGuard({
      recoveryAttempt: { id: "rec_2", merchantId: "merchant_alpha", status: "APPROVED", strategy: "RETRY" },
      transaction: { merchantId: "merchant_alpha" },
      merchantPolicy: { maxAutomaticRetries: 1, autonomyMode: "MANUAL" },
      merchantId: "merchant_alpha",
      previousAttempts: [
        { id: "rec_1", strategy: "RETRY", status: "SIMULATED" },
      ],
      simulation: true,
    });

    assert.strictEqual(guard.allowed, false);
    assert.strictEqual(guard.status, "BLOCKED");
  });

  it("Requires operator confirmation in ASSISTED mode for live execution", () => {
    const guard = executor.validateExecutionGuard({
      recoveryAttempt: { id: "rec_1", merchantId: "merchant_alpha", status: "APPROVED", strategy: "RETRY" },
      transaction: { merchantId: "merchant_alpha" },
      merchantPolicy: { maxAutomaticRetries: 1, autonomyMode: "ASSISTED" },
      merchantId: "merchant_alpha",
      previousAttempts: [],
      simulation: false, // Live execution request
      confirmed: false, // Not yet confirmed
    });

    assert.strictEqual(guard.allowed, false);
    assert.strictEqual(guard.status, "REQUIRES_CONFIRMATION");
  });
});

describe("BackendRecoveryExecutor - Simulation, Idempotency & Audit Trails", () => {
  it("Executes simulation cleanly without calling Razorpay and records audit log", async () => {
    const mockDb = createMockDb({
      "recovery_attempts/rec_sim_01": {
        merchantId: "merchant_alpha",
        transactionId: "tx_01",
        status: "APPROVED",
        strategy: "RETRY",
        attemptNumber: 1,
      },
      "transactions/tx_01": {
        id: "tx_01",
        merchantId: "merchant_alpha",
        amount: 2499,
        status: "FAILED",
      },
      "merchant_policies/merchant_alpha": {
        merchantId: "merchant_alpha",
        autonomyMode: "MANUAL",
        maxAutomaticRetries: 1,
      },
    });

    const executor = new BackendRecoveryExecutor({ firestore: mockDb });

    const result = await executor.executeRecovery({
      merchantId: "merchant_alpha",
      transactionId: "tx_01",
      recoveryAttemptId: "rec_sim_01",
      simulation: true,
    });

    assert.strictEqual(result.success, true);
    assert.strictEqual(result.status, "SIMULATED_SUCCESS");
    assert.strictEqual(result.simulated, true);
    assert.strictEqual(result.executionId, "exec_rec_sim_01");

    // Verify recovery attempt was updated to SIMULATED
    const updatedAttempt = mockDb._store["recovery_attempts/rec_sim_01"];
    assert.strictEqual(updatedAttempt.status, "SIMULATED");
    assert.strictEqual(updatedAttempt.simulated, true);

    // Verify audit log recorded
    assert.strictEqual(mockDb._auditLogs.length, 1);
    assert.strictEqual(mockDb._auditLogs[0].action, "RECOVERY_EXECUTION");
    assert.strictEqual(mockDb._auditLogs[0].simulated, true);
  });

  it("Idempotency: Replaying the same recovery execution request returns existing result", async () => {
    const mockDb = createMockDb({
      "processed_recoveries/exec_rec_sim_01": {
        success: true,
        status: "SIMULATED_SUCCESS",
        simulated: true,
        executionId: "exec_rec_sim_01",
        transactionId: "tx_01",
        recoveryAttemptId: "rec_sim_01",
      },
      "recovery_attempts/rec_sim_01": {
        merchantId: "merchant_alpha",
        transactionId: "tx_01",
        status: "SIMULATED",
        strategy: "RETRY",
      },
      "transactions/tx_01": {
        id: "tx_01",
        merchantId: "merchant_alpha",
        amount: 2499,
        status: "FAILED",
      },
    });

    const executor = new BackendRecoveryExecutor({ firestore: mockDb });

    const result = await executor.executeRecovery({
      merchantId: "merchant_alpha",
      transactionId: "tx_01",
      recoveryAttemptId: "rec_sim_01",
      simulation: true,
    });

    assert.strictEqual(result.isDuplicate, true);
    assert.strictEqual(result.status, "DUPLICATE");
  });
});
