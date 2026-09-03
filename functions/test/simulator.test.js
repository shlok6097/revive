const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const { SimulatorService, SCENARIO_PRESETS } = require("../services/simulator_service");

describe("SimulatorService - Payment Failure Simulator & Demo Engine", () => {
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

  test("Generates simulated failed transaction with simulated flag and audit trail", async () => {
    const mockDb = createMockDb();
    const service = new SimulatorService({ firestore: mockDb });

    const result = await service.runPaymentSimulation({
      merchantId: "merchant_alpha",
      scenarioId: "BANK_DECLINE",
    });

    assert.equal(result.success, true);
    assert.equal(result.simulated, true);
    assert.ok(result.transactionId.startsWith("tx_sim_"));

    const storedTx = mockDb.collections.transactions.get(result.transactionId);
    assert.ok(storedTx);
    assert.equal(storedTx.simulated, true);
    assert.equal(storedTx.status, "FAILED");
    assert.equal(storedTx.bank, "HDFC");
    assert.equal(storedTx.errorCode, "BAD_REQUEST_ERROR");
    assert.equal(storedTx.amount, 1250.0);

    const startAudit = mockDb.collections.audit_logs.find((a) => a.action === "SIMULATION_STARTED");
    const createAudit = mockDb.collections.audit_logs.find((a) => a.action === "SIMULATION_TRANSACTION_CREATED");
    assert.ok(startAudit);
    assert.ok(createAudit);
    assert.equal(createAudit.simulated, true);
  });

  test("Configures realistic telemetry for all standard failure scenario presets", async () => {
    const mockDb = createMockDb();
    const service = new SimulatorService({ firestore: mockDb });

    for (const key of Object.keys(SCENARIO_PRESETS)) {
      const res = await service.runPaymentSimulation({
        merchantId: "merchant_alpha",
        scenarioId: key,
      });

      assert.equal(res.success, true);
      const tx = mockDb.collections.transactions.get(res.transactionId);
      assert.equal(tx.errorCode, SCENARIO_PRESETS[key].errorCode);
      assert.equal(tx.simulated, true);
    }
  });

  test("Simulate Customer Payment Success reconciles simulated transaction, session, and attempt", async () => {
    const mockDb = createMockDb();
    const service = new SimulatorService({ firestore: mockDb });

    const txId = "tx_sim_reconcile_01";
    const sesId = "ses_sim_reconcile_01";
    const attId = "att_sim_reconcile_01";

    mockDb.collections.transactions.set(txId, {
      merchantId: "merchant_alpha",
      status: "FAILED",
      simulated: true,
    });

    mockDb.collections.recovery_sessions.set(sesId, {
      merchantId: "merchant_alpha",
      transactionId: txId,
      recoveryAttemptId: attId,
      status: "ACTIVE",
    });

    mockDb.collections.recovery_attempts.set(attId, {
      merchantId: "merchant_alpha",
      status: "SIMULATED",
    });

    const result = await service.simulateCustomerPaymentSuccess({
      sessionId: sesId,
      transactionId: txId,
    });

    assert.equal(result.success, true);
    assert.equal(result.status, "RECOVERED");

    const tx = mockDb.collections.transactions.get(txId);
    assert.equal(tx.status, "SUCCESS");
    assert.equal(tx.recoveryOutcome, "RECOVERED");

    const ses = mockDb.collections.recovery_sessions.get(sesId);
    assert.equal(ses.status, "USED");

    const att = mockDb.collections.recovery_attempts.get(attId);
    assert.equal(att.status, "COMPLETED");

    const audit = mockDb.collections.audit_logs.find((a) => a.action === "SIMULATION_RECONCILED");
    assert.ok(audit);
    assert.equal(audit.simulated, true);
  });

  test("Security Invariant: Rejects simulated payment reconciliation for live transactions", async () => {
    const mockDb = createMockDb();
    const service = new SimulatorService({ firestore: mockDb });

    const liveTxId = "tx_live_prod_99";
    mockDb.collections.transactions.set(liveTxId, {
      merchantId: "merchant_alpha",
      status: "FAILED",
      simulated: false, // Live production transaction
    });

    await assert.rejects(
      async () => {
        await service.simulateCustomerPaymentSuccess({
          sessionId: "ses_any",
          transactionId: liveTxId,
        });
      },
      /Security Violation/
    );
  });
});
