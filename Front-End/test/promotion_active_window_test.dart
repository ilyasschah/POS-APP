// Pins how a promotion's four scheduling fields are read.
//
// The reported bug: "Black Friday", enabled, Every day, 2026-08-22 22:17:00 →
// 2026-08-24 22:18:00, sat on "Inactive" on 23 Aug at every hour of the day.
// The old rule enforced the time pair as a time-of-day window on EVERY day of
// the range, so a promotion the operator meant to run for two straight days was
// live for 60 seconds a day and dead for the other 1439 minutes.
//
// Start/End are now instants: date + time on each end. The daily-window reading
// is kept only for date-less promotions (open-ended happy hour).
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/api/promotion_models.dart';
import 'package:pos_app/promotions/promotion_provider.dart';

PromotionDto promo({
  DateTime? startDate,
  String? startTime,
  DateTime? endDate,
  String? endTime,
  int daysOfWeek = 127,
  bool isEnabled = true,
}) =>
    PromotionDto(
      id: 1,
      companyId: 1,
      name: 'Black Friday',
      startDate: startDate,
      startTime: startTime,
      endDate: endDate,
      endTime: endTime,
      daysOfWeek: daysOfWeek,
      isEnabled: isEnabled,
    );

void main() {
  group('multi-day span (the reported bug)', () {
    final blackFriday = promo(
      startDate: DateTime(2026, 8, 22),
      startTime: '22:17:00',
      endDate: DateTime(2026, 8, 24),
      endTime: '22:18:00',
    );

    test('live all day on the middle day, not just 22:17-22:18', () {
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 23, 0, 5)), isTrue);
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 23, 13, 30)), isTrue);
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 23, 22, 17, 30)), isTrue);
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 23, 23, 59)), isTrue);
    });

    test('the start time still gates the first day', () {
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 22, 22, 16, 59)), isFalse);
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 22, 22, 17)), isTrue);
    });

    test('the end time still closes the last day', () {
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 24, 22, 18)), isTrue);
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 24, 22, 18, 1)), isFalse);
    });

    test('dead outside the range', () {
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 21, 23, 59)), isFalse);
      expect(isPromotionActiveNow(blackFriday, DateTime(2026, 8, 25, 0, 1)), isFalse);
    });
  });

  group('boundary defaults', () {
    test('dates with no times cover both full days', () {
      final p = promo(
        startDate: DateTime(2026, 8, 22),
        endDate: DateTime(2026, 8, 24),
      );
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 22, 0, 0)), isTrue);
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 24, 23, 59, 59)), isTrue);
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 25)), isFalse);
    });

    test('open-ended start runs forever', () {
      final p = promo(startDate: DateTime(2026, 8, 22), startTime: '09:00');
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 22, 8, 59)), isFalse);
      expect(isPromotionActiveNow(p, DateTime(2027, 1, 1, 3, 0)), isTrue);
    });

    test('single-day promotion keeps its intra-day window', () {
      final p = promo(
        startDate: DateTime(2026, 8, 23),
        startTime: '10:00',
        endDate: DateTime(2026, 8, 23),
        endTime: '14:00',
      );
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 23, 9, 59)), isFalse);
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 23, 12, 0)), isTrue);
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 23, 14, 1)), isFalse);
    });
  });

  group('date-less promotions keep the daily window', () {
    final happyHour = promo(startTime: '17:00', endTime: '19:00');

    test('recurs every day', () {
      expect(isPromotionActiveNow(happyHour, DateTime(2026, 8, 23, 16, 59)), isFalse);
      expect(isPromotionActiveNow(happyHour, DateTime(2026, 8, 23, 18, 0)), isTrue);
      expect(isPromotionActiveNow(happyHour, DateTime(2027, 3, 9, 18, 0)), isTrue);
      expect(isPromotionActiveNow(happyHour, DateTime(2027, 3, 9, 19, 1)), isFalse);
    });

    test('zero-width window is treated as all day', () {
      final p = promo(startTime: '20:20', endTime: '20:20');
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 23, 4, 0)), isTrue);
    });
  });

  group('other gates still apply', () {
    test('disabled is never active', () {
      final p = promo(
        startDate: DateTime(2026, 8, 22),
        endDate: DateTime(2026, 8, 24),
        isEnabled: false,
      );
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 23, 12)), isFalse);
    });

    test('day-of-week bitmask filters days inside the span', () {
      // Weekends only (Sat=bit5, Sun=bit6) = 96. 2026-08-23 is a Sunday.
      final p = promo(
        startDate: DateTime(2026, 8, 22),
        endDate: DateTime(2026, 8, 28),
        daysOfWeek: 96,
      );
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 23, 12)), isTrue);
      expect(isPromotionActiveNow(p, DateTime(2026, 8, 25, 12)), isFalse);
    });
  });
}
