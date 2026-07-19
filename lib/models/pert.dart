import 'dart:math' as math;

class PertEstimate {
  const PertEstimate({
    required this.optimistic,
    required this.mostLikely,
    required this.pessimistic,
  });

  final double optimistic;
  final double mostLikely;
  final double pessimistic;

  double get expected => (optimistic + 4 * mostLikely + pessimistic) / 6;
  double get standardDeviation => (pessimistic - optimistic) / 6;
  double get variance => standardDeviation * standardDeviation;

  String? get validationError {
    if (!optimistic.isFinite || !mostLikely.isFinite || !pessimistic.isFinite) {
      return 'All estimates must be valid numbers.';
    }
    if (optimistic <= 0 || mostLikely <= 0 || pessimistic <= 0) {
      return 'O, M and P must all be greater than zero.';
    }
    if (optimistic > mostLikely || mostLikely > pessimistic) {
      return 'Use the order O ≤ M ≤ P.';
    }
    return null;
  }

  bool get isValid => validationError == null;

  Map<String, Object> toJson() => <String, Object>{
    'optimistic': optimistic,
    'mostLikely': mostLikely,
    'pessimistic': pessimistic,
  };

  factory PertEstimate.fromJson(Map<String, dynamic> json) => PertEstimate(
    optimistic: (json['optimistic'] as num).toDouble(),
    mostLikely: (json['mostLikely'] as num).toDouble(),
    pessimistic: (json['pessimistic'] as num).toDouble(),
  );
}

class PertStats {
  const PertStats({
    required this.optimistic,
    required this.mostLikely,
    required this.pessimistic,
    required this.expected,
    required this.variance,
  });

  factory PertStats.fromEstimate(PertEstimate estimate) => PertStats(
    optimistic: estimate.optimistic,
    mostLikely: estimate.mostLikely,
    pessimistic: estimate.pessimistic,
    expected: estimate.expected,
    variance: estimate.variance,
  );

  factory PertStats.chain(Iterable<PertStats> values) {
    var optimistic = 0.0;
    var mostLikely = 0.0;
    var pessimistic = 0.0;
    var expected = 0.0;
    var variance = 0.0;
    for (final value in values) {
      optimistic += value.optimistic;
      mostLikely += value.mostLikely;
      pessimistic += value.pessimistic;
      expected += value.expected;
      variance += value.variance;
    }
    return PertStats(
      optimistic: optimistic,
      mostLikely: mostLikely,
      pessimistic: pessimistic,
      expected: expected,
      variance: variance,
    );
  }

  final double optimistic;
  final double mostLikely;
  final double pessimistic;
  final double expected;
  final double variance;

  double get standardDeviation => math.sqrt(variance);

  Duration get expectedDuration =>
      Duration(milliseconds: (expected * 60000).round());
}
