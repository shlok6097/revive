/// Metric distribution for a specific payment failure category.
class FailureCategoryAnalytics {
  const FailureCategoryAnalytics({
    required this.category,
    required this.count,
    required this.percentage,
    required this.amount,
  });

  final String category;
  final int count;
  final double percentage;
  final double amount;

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'count': count,
      'percentage': percentage,
      'amount': amount,
    };
  }
}

/// Metric breakdown for a specific banking institution.
class BankFailureAnalytics {
  const BankFailureAnalytics({
    required this.bank,
    required this.failureCount,
    required this.recoveredCount,
    required this.failurePercentage,
    required this.amount,
  });

  final String bank;
  final int failureCount;
  final int recoveredCount;
  final double failurePercentage;
  final double amount;

  Map<String, dynamic> toMap() {
    return {
      'bank': bank,
      'failureCount': failureCount,
      'recoveredCount': recoveredCount,
      'failurePercentage': failurePercentage,
      'amount': amount,
    };
  }
}

/// Metric breakdown for a specific payment instrument (UPI, Card, Netbanking).
class PaymentMethodAnalytics {
  const PaymentMethodAnalytics({
    required this.paymentMethod,
    required this.totalCount,
    required this.failedCount,
    required this.recoveredCount,
    required this.sharePercentage,
    required this.amount,
  });

  final String paymentMethod;
  final int totalCount;
  final int failedCount;
  final int recoveredCount;
  final double sharePercentage;
  final double amount;

  Map<String, dynamic> toMap() {
    return {
      'paymentMethod': paymentMethod,
      'totalCount': totalCount,
      'failedCount': failedCount,
      'recoveredCount': recoveredCount,
      'sharePercentage': sharePercentage,
      'amount': amount,
    };
  }
}
