import 'package:flutter_test/flutter_test.dart';
import 'package:sdbs/utils/validators.dart';
import 'package:sdbs/services/decision_service.dart';

void main() {
  group('Validators Tests', () {
    test('Email validation', () {
      expect(Validators.email('test@gmail.com'), null);
      expect(Validators.email('invalid-email'), 'Invalid email address');
      expect(Validators.email(''), 'Email is required');
    });

    test('Jordan Phone validation', () {
      expect(Validators.jordanPhone('0771234567'), null);
      expect(Validators.jordanPhone('+962791234567'), null);
      expect(Validators.jordanPhone('1234567'), 'Invalid Jordan mobile number');
      expect(Validators.jordanPhone(''), 'Phone is required');
    });

    test('Password strength validation', () {
      expect(Validators.password('Password123!'), null);
      expect(Validators.password('short'), 'Minimum 8 characters');
      expect(Validators.password('nocapital1!'), 'At least one capital letter');
      expect(Validators.password('NoDigit!'), 'At least one digit');
      expect(Validators.password('NoSpecial1'), 'At least one special character');
    });
  });

  group('DecisionService Engine Tests (Capacity-Aware)', () {
    // ── Rule 1: No demand → SKIP ─────────────────────────────────

    test('Rule 1: SKIP when waitingCount == 0 (regardless of occupancy)', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 0,
        occupancy: 10,
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionSkip);
      expect(result.reason, 'No passengers waiting');
    });

    // ── Rule 2: Bus full → SKIP ───────────────────────────────────

    test('Rule 2: SKIP when bus is exactly at capacity (occupancy == busCapacity)', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 10,
        occupancy: 50,
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionSkip);
      expect(result.reason, 'Bus full — cannot board passengers');
    });

    test('Rule 2: SKIP when bus is over capacity (occupancy > busCapacity)', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 10,
        occupancy: 9999, // Camera edge case from the question
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionSkip);
      expect(result.reason, 'Bus full — cannot board passengers');
    });

    // ── Rule 3: Demand exceeds available seats → STOP with warning ─

    test('Rule 3: STOP (limited space) when waitingCount > availableSeats', () {
      // 10 waiting, only 3 seats left (50 - 47 = 3)
      final result = DecisionService.calculateDecision(
        waitingCount: 10,
        occupancy: 47,
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionStop);
      expect(result.reason, contains('Limited space'));
      expect(result.reason, contains('3 seats left'));
    });

    // ── Rule 4: High demand + sufficient space → EARLY DEPART ─────

    test('Rule 4: EARLY DEPART when waiting >= threshold AND space available', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 20,
        occupancy: 10,
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionEarly);
      expect(result.reason, contains('High demand'));
      expect(result.reason, contains('40 seats available'));
    });

    test('Rule 4: EARLY DEPART when waiting > threshold AND space available', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 35,
        occupancy: 5,
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionEarly);
    });

    // ── Rule 5: Normal STOP ───────────────────────────────────────

    test('Rule 5: STOP (normal) when waiting > 0 and waiting < threshold and seats available', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 5,
        occupancy: 10,
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionStop);
      expect(result.reason, 'Passengers waiting');
    });

    // ── Backward-compatibility (no busCapacity provided) ─────────

    test('Backward compat: default busCapacity=50 used when omitted', () {
      // Occupancy 10, waiting 5, threshold 20 → normal STOP
      final result = DecisionService.calculateDecision(
        waitingCount: 5,
        occupancy: 10,
        maxThreshold: 20,
      );
      expect(result.action, DecisionService.actionStop);
    });

    // ── The exact scenario from the user's question ───────────────

    test("User scenario: occupancy=9999, waiting=10, threshold=20 → SKIP (bus full)", () {
      final result = DecisionService.calculateDecision(
        waitingCount: 10,
        occupancy: 9999,
        maxThreshold: 20,
        busCapacity: 50,
      );
      // Bus is full → cannot board → SKIP and notify waiting passengers
      expect(result.action, DecisionService.actionSkip);
      expect(result.reason, 'Bus full — cannot board passengers');
    });

    // ── Boundary Cases ───────────────────────────────────────────

    test('Boundary: 1 seat left, 1 waiting → STOP (exactly fits)', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 1,
        occupancy: 49,
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionStop);
    });

    test('Boundary: 1 seat left, 2 waiting → STOP (limited space)', () {
      final result = DecisionService.calculateDecision(
        waitingCount: 2,
        occupancy: 49,
        maxThreshold: 20,
        busCapacity: 50,
      );
      expect(result.action, DecisionService.actionStop);
      expect(result.reason, contains('1 seats left'));
    });
  });

}
