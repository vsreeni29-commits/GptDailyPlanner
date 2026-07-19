import 'package:flutter_test/flutter_test.dart';
import 'package:pert_daily_planner/models/pert.dart';

void main() {
  group('PERT calculations', () {
    test('uses the three-point expected-time formula', () {
      const estimate = PertEstimate(
        optimistic: 10,
        mostLikely: 20,
        pessimistic: 40,
      );

      expect(estimate.expected, 130 / 6);
      expect(estimate.standardDeviation, 5);
      expect(estimate.variance, 25);
      expect(estimate.validationError, isNull);
    });

    test('requires positive ordered estimates', () {
      expect(
        const PertEstimate(
          optimistic: 0,
          mostLikely: 10,
          pessimistic: 20,
        ).validationError,
        contains('greater than zero'),
      );
      expect(
        const PertEstimate(
          optimistic: 15,
          mostLikely: 10,
          pessimistic: 20,
        ).validationError,
        contains('O ≤ M ≤ P'),
      );
    });

    test('chains expected times and variances', () {
      final chain = PertStats.chain(<PertStats>[
        PertStats.fromEstimate(
          const PertEstimate(optimistic: 10, mostLikely: 20, pessimistic: 40),
        ),
        PertStats.fromEstimate(
          const PertEstimate(optimistic: 5, mostLikely: 10, pessimistic: 17),
        ),
      ]);

      expect(chain.expected, closeTo((130 + 62) / 6, 0.0001));
      expect(chain.variance, closeTo(29, 0.0001));
      expect(chain.standardDeviation, closeTo(5.38516, 0.0001));
    });
  });
}
