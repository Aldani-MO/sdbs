import 'package:flutter_test/flutter_test.dart';
import 'package:sdbs/services/decision_service.dart';

/// Unit tests for the Capacity-Aware Decision Engine Algorithm
/// Tests the core STOP / SKIP / EARLY DEPART decision logic
/// considering both passenger demand (waiting) and bus supply (capacity).

void main() {
  group('Decision Engine - STOP Decisions (Normal & Limited Space)', () {
    test('Should return STOP when passengers waiting and below threshold and space exists', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 5, occupancy: 20, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('STOP'));
    });

    test('Should return STOP when 1 passenger waiting and space exists', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 1, occupancy: 0, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('STOP'));
    });

    test('Should return STOP when many passengers waiting but under threshold', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 15, occupancy: 30, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('STOP'));
    });

    test('Should return STOP with Warning when demand exceeds available seats', () {
      // 30 waiting, but only 10 seats left (50-40)
      final result = DecisionService.calculateDecision(
        waitingCount: 30, occupancy: 40, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('STOP'));
      expect(result.reason, contains('Limited space'));
    });
  });

  group('Decision Engine - SKIP Decisions', () {
    test('Should return SKIP when no passengers waiting', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 0, occupancy: 20, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('SKIP'));
      expect(result.reason, contains('No passengers'));
    });

    test('Should return SKIP when no passengers and bus is empty', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 0, occupancy: 0, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('SKIP'));
    });

    test('Should return SKIP when bus is exactly full, even if people waiting', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 10, occupancy: 50, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('SKIP'));
      expect(result.reason, contains('Bus full'));
    });

    test('Should return SKIP when bus is over capacity, even if people waiting', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 15, occupancy: 999, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('SKIP'));
    });
  });

  group('Decision Engine - EARLY DEPART Decisions', () {
    test('Should return EARLY DEPART when waiting equals threshold AND space exists', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 50, occupancy: 10, maxThreshold: 50, busCapacity: 100, // Large bus
      );
      expect(result.action, equals('EARLY DEPART'));
      expect(result.reason, contains('demand'));
    });

    test('Should return EARLY DEPART when waiting exceeds threshold AND space exists', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 55, occupancy: 10, maxThreshold: 50, busCapacity: 100,
      );
      expect(result.action, equals('EARLY DEPART'));
    });

    test('Should return EARLY DEPART when waiting far exceeds threshold', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 100, occupancy: 5, maxThreshold: 50, busCapacity: 200,
      );
      expect(result.action, equals('EARLY DEPART'));
    });
  });

  group('Decision Engine - Priority Order', () {
    test('SKIP (No Demand) is checked first: waiting=0 always means SKIP', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 0, occupancy: 999, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('SKIP'));
    });

    test('SKIP (Full Bus) overrides EARLY DEPART', () {
      // High demand (50) >= Threshold (50), but bus is full (occupancy 50)
      final result = DecisionService.calculateDecision(
        waitingCount: 50, occupancy: 50, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('SKIP'));
    });

    test('STOP (Limited Space) overrides EARLY DEPART', () {
      // High demand (50) >= Threshold (50), but only 10 seats left
      final result = DecisionService.calculateDecision(
        waitingCount: 50, occupancy: 40, maxThreshold: 50, busCapacity: 50,
      );
      expect(result.action, equals('STOP'));
      expect(result.reason, contains('Limited space'));
    });
  });

  group('Decision Engine - Backward Compatibility & Edge Cases', () {
    test('Should default to busCapacity 50 when omitted', () {
      // Occupancy 50, default capacity is 50 -> Bus Full -> SKIP
      final result = DecisionService.calculateDecision(
        waitingCount: 5, occupancy: 50, maxThreshold: 20,
      );
      expect(result.action, equals('SKIP'));
    });

    test('Bug fix scenario: waiting=10, occupancy=21, threshold=20, capacity=50 → STOP', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 10, occupancy: 21, maxThreshold: 20, busCapacity: 50,
      );
      // waiting (10) < threshold (20), available seats (29) > waiting (10) -> normal STOP
      expect(result.action, equals('STOP'));
    });

    test('Should handle threshold of 1 with 1 waiting AND space exists → EARLY DEPART', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 1, occupancy: 0, maxThreshold: 1, busCapacity: 50,
      );
      expect(result.action, equals('EARLY DEPART'));
    });

    test('Should handle extremely large numbers properly', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 500, occupancy: 200, maxThreshold: 1000, busCapacity: 1000,
      );
      // Waiting < threshold, space available (800) > waiting (500) -> STOP
      expect(result.action, equals('STOP'));
    });

    test('DecisionResult contains action and reason fields', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 5, occupancy: 10, maxThreshold: 20, busCapacity: 50,
      );
      expect(result.action, isNotNull);
      expect(result.reason, isNotNull);
      expect(result.action, isNotEmpty);
      expect(result.reason, isNotEmpty);
    });
  });
}
