import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ai_decision.dart';
import '../models/transaction.dart';

/// Structured result returned from AI payment failure analysis.
class AIDecisionResult {
  const AIDecisionResult({
    required this.failureCategory,
    required this.recommendedStrategy,
    this.modelName = 'Phi-3-mini-4k-instruct-q4',
    this.modelVersion = 'v1.0',
    this.promptVersion = 'revive-payment-classifier-v1',
    this.reasoning,
    this.rawResponse,
    this.isFallback = false,
  });

  final String failureCategory;
  final String recommendedStrategy;
  final String modelName;
  final String modelVersion;
  final String promptVersion;
  final String? reasoning;
  final String? rawResponse;
  final bool isFallback;

  AIDecision toDecision({
    required String id,
    required String merchantId,
    required String transactionId,
    String policyStatus = 'REQUIRES_REVIEW',
  }) {
    return AIDecision(
      id: id,
      merchantId: merchantId,
      transactionId: transactionId,
      failureCategory: failureCategory,
      recommendedStrategy: recommendedStrategy,
      confidence: null, // Confidence scores are not trusted/invented by LLM in Phase 5
      modelName: modelName,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      reasoning: reasoning,
      policyStatus: policyStatus,
      createdAt: DateTime.now(),
    );
  }
}

/// Abstract interface for AI failure classification providers.
///
/// Ensures REVIVE is decoupled from specific LLM models or hosting vendors.
abstract class AIService {
  Future<AIDecisionResult> classifyPaymentFailure({
    required TransactionModel transaction,
    String? merchantId,
  });
}

/// Local LLM service client communicating with the OpenAI-compatible llama-server endpoint.
///
/// SECURITY INVARIANT:
/// Only transaction telemetry (amount, error codes, reason) is provided in prompts.
/// Secret keys, auth tokens, passwords, and sensitive PII are never sent to the model.
class LocalLLMService implements AIService {
  LocalLLMService({
    String? baseUrl,
    this.modelName = 'Phi-3-mini-4k-instruct-q4.gguf',
    this.modelVersion = 'v1.0',
    this.promptVersion = 'revive-payment-classifier-v1',
    http.Client? httpClient,
  })  : baseUrl = baseUrl ?? 'http://127.0.0.1:8080',
        _client = httpClient ?? http.Client();

  final String baseUrl;
  final String modelName;
  final String modelVersion;
  final String promptVersion;
  final http.Client _client;

  static const String systemPrompt =
      "You are REVIVE's payment failure classification engine. "
      "Your job is to classify payment failures and recommend a possible recovery strategy. "
      "Return ONLY one JSON object. Do not use markdown. Do not use code fences. "
      "Do not add explanations outside JSON. "
      "failureCategory must be exactly one of: "
      "BANK_DECLINE, INSUFFICIENT_FUNDS, NETWORK_ERROR, INVALID_DETAILS, AUTHENTICATION_FAILURE, FRAUD_RISK, UNKNOWN. "
      "recommendedStrategy must be exactly one of: "
      "RETRY, ALTERNATIVE_METHOD, WAIT_AND_RETRY, NO_ACTION, ESCALATE. "
      'Return exactly: { "failureCategory": "...", "recommendedStrategy": "..." }';

  @override
  Future<AIDecisionResult> classifyPaymentFailure({
    required TransactionModel transaction,
    String? merchantId,
  }) async {
    // 1. Construct minimal telemetry payload (strictly zero secrets/PII)
    final telemetry = {
      'amount': transaction.amount,
      'currency': transaction.currency,
      'paymentMethod': transaction.paymentMethod,
      'bank': transaction.bank,
      'errorCode': transaction.errorCode,
      'errorReason': transaction.errorReason,
      'errorSource': transaction.errorSource,
      'errorStep': transaction.errorStep,
    };

    final requestBody = jsonEncode({
      'model': modelName,
      'temperature': 0,
      'max_tokens': 150,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': jsonEncode(telemetry)},
      ],
    });

    try {
      final uri = Uri.parse('$baseUrl/v1/chat/completions');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices.first['message'] as Map<String, dynamic>?;
          final content = message?['content'] as String? ?? '';
          return sanitizeAndParse(content, rawResponse: response.body);
        }
      }
    } catch (_) {
      // Local server unavailable, network timeout, or CORS block in browser
    }

    // Heuristic fallback for offline/development resilience
    return _heuristicFallback(transaction);
  }

  /// Robust parser for LLM response content:
  /// 1. Trims whitespace
  /// 2. Strips markdown fences (```json ... ```)
  /// 3. Extracts JSON substring if surrounding text exists
  /// 4. Validates required fields and enum bounds
  /// 5. Controlled fallback on any parse failure
  AIDecisionResult sanitizeAndParse(String content, {String? rawResponse}) {
    try {
      var sanitized = content.trim();

      // Strip markdown code fences (e.g. ```json ... ``` or ``` ... ```)
      if (sanitized.startsWith('```')) {
        final lines = sanitized.split('\n');
        if (lines.isNotEmpty && lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.isNotEmpty && lines.last.trim() == '```') {
          lines.removeLast();
        }
        sanitized = lines.join('\n').trim();
      }

      // If text still surrounds the JSON object, extract { ... } using regex
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(sanitized);
      if (jsonMatch != null) {
        sanitized = jsonMatch.group(0)!;
      }

      final parsed = jsonDecode(sanitized) as Map<String, dynamic>;

      final rawCat = parsed['failureCategory'] as String?;
      final rawStrat = parsed['recommendedStrategy'] as String?;

      // Strictly validate against known enum sets
      final cat = FailureCategory.fromString(rawCat);
      final strat = RecommendedStrategy.fromString(rawStrat);

      // If category was unrecognized or invalid enum, reject / mark unknown
      if (rawCat == null || !FailureCategory.values.any((e) => e.value == rawCat.trim().toUpperCase())) {
        return AIDecisionResult(
          failureCategory: FailureCategory.unknown.value,
          recommendedStrategy: RecommendedStrategy.escalate.value,
          modelName: modelName,
          modelVersion: modelVersion,
          promptVersion: promptVersion,
          reasoning: 'Invalid or unrecognized failureCategory enum from model.',
          rawResponse: rawResponse ?? content,
          isFallback: true,
        );
      }

      // If strategy was unrecognized or invalid enum, reject / fallback to escalate
      if (rawStrat == null || !RecommendedStrategy.values.any((e) => e.value == rawStrat.trim().toUpperCase())) {
        return AIDecisionResult(
          failureCategory: cat.value,
          recommendedStrategy: RecommendedStrategy.escalate.value,
          modelName: modelName,
          modelVersion: modelVersion,
          promptVersion: promptVersion,
          reasoning: 'Invalid or unrecognized recommendedStrategy enum from model.',
          rawResponse: rawResponse ?? content,
          isFallback: true,
        );
      }

      return AIDecisionResult(
        failureCategory: cat.value,
        recommendedStrategy: strat.value,
        modelName: modelName,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        reasoning: parsed['reasoning'] as String? ?? parsed['reason'] as String?,
        rawResponse: rawResponse ?? content,
        isFallback: false,
      );
    } catch (e) {
      // Parse exception: return controlled fallback without crashing
      return AIDecisionResult(
        failureCategory: FailureCategory.unknown.value,
        recommendedStrategy: RecommendedStrategy.escalate.value,
        modelName: modelName,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        reasoning: 'Malformed model output; defaulted to safe fallback.',
        rawResponse: rawResponse ?? content,
        isFallback: true,
      );
    }
  }

  AIDecisionResult _heuristicFallback(TransactionModel tx) {
    final reason = (tx.errorReason ?? '').toLowerCase();
    final code = (tx.errorCode ?? '').toLowerCase();
    final source = (tx.errorSource ?? '').toLowerCase();

    if (reason.contains('insufficient') || code.contains('insufficient') || reason.contains('low balance')) {
      return AIDecisionResult(
        failureCategory: FailureCategory.insufficientFunds.value,
        recommendedStrategy: RecommendedStrategy.waitAndRetry.value,
        modelName: modelName,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        reasoning: 'Heuristic classification: Insufficient customer account balance detected.',
        isFallback: true,
      );
    }

    if (reason.contains('timeout') || code.contains('timeout') || reason.contains('network') || source.contains('gateway')) {
      return AIDecisionResult(
        failureCategory: FailureCategory.networkError.value,
        recommendedStrategy: RecommendedStrategy.retry.value,
        modelName: modelName,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        reasoning: 'Heuristic classification: Gateway/network timeout detected.',
        isFallback: true,
      );
    }

    if (reason.contains('invalid') || code.contains('invalid') || reason.contains('incorrect') || reason.contains('expired')) {
      return AIDecisionResult(
        failureCategory: FailureCategory.invalidDetails.value,
        recommendedStrategy: RecommendedStrategy.alternativeMethod.value,
        modelName: modelName,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        reasoning: 'Heuristic classification: Invalid card or payment credentials.',
        isFallback: true,
      );
    }

    if (reason.contains('auth') || reason.contains('mpin') || reason.contains('otp') || code.contains('auth')) {
      return AIDecisionResult(
        failureCategory: FailureCategory.authenticationFailure.value,
        recommendedStrategy: RecommendedStrategy.alternativeMethod.value,
        modelName: modelName,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        reasoning: 'Heuristic classification: Customer authentication / 3DS failure.',
        isFallback: true,
      );
    }

    if (reason.contains('decline') || source.contains('bank') || code.contains('bank')) {
      return AIDecisionResult(
        failureCategory: FailureCategory.bankDecline.value,
        recommendedStrategy: RecommendedStrategy.escalate.value,
        modelName: modelName,
        modelVersion: modelVersion,
        promptVersion: promptVersion,
        reasoning: 'Heuristic classification: Issuing bank declined transaction.',
        isFallback: true,
      );
    }

    return AIDecisionResult(
      failureCategory: FailureCategory.unknown.value,
      recommendedStrategy: RecommendedStrategy.escalate.value,
      modelName: modelName,
      modelVersion: modelVersion,
      promptVersion: promptVersion,
      reasoning: 'Heuristic classification: Unknown failure state.',
      isFallback: true,
    );
  }
}

/// Mock AI service for tests and offline development simulations.
class MockAIService implements AIService {
  MockAIService({this.customResult});

  final AIDecisionResult? customResult;

  @override
  Future<AIDecisionResult> classifyPaymentFailure({
    required TransactionModel transaction,
    String? merchantId,
  }) async {
    if (customResult != null) return customResult!;

    return LocalLLMService()._heuristicFallback(transaction);
  }
}
