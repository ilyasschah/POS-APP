// Guards the shape detection behind `14_date_format_test`.
//
// That test decides whether a screen follows the date-format setting by looking
// for date SHAPES in the screen's text. Two ways that can go wrong, and both
// would be quiet:
//
//   * a false NEGATIVE — the shapes fail to tell each other apart, so a screen
//     showing the wrong format passes;
//   * a false POSITIVE — something that is not a date at all (a document number,
//     a barcode, a phone number) reads as one, so a perfectly correct screen
//     fails and the real signal gets ignored as flaky.
//
// The strings below are taken from real runs of this suite.
import 'package:flutter_test/flutter_test.dart';

import '../integration_test/helpers/date_format_helper.dart';

void main() {
  group('the three shapes tell each other apart', () {
    test('ISO matches only the year-first form', () {
      expect(DateShape.iso.regex.hasMatch('2026-09-01'), isTrue);
      expect(
        DateShape.iso.regex.hasMatch('01-09-2026'),
        isFalse,
        reason: 'A day-first date must not read as ISO, or switching between '
            'the two settings would prove nothing.',
      );
      expect(DateShape.iso.regex.hasMatch('01/09/2026'), isFalse);
    });

    test('dashed matches only the day-first dashed form', () {
      expect(DateShape.dashed.regex.hasMatch('01-09-2026'), isTrue);
      expect(DateShape.dashed.regex.hasMatch('2026-09-01'), isFalse);
    });

    test('slashed matches the slashed form, either ordering', () {
      expect(DateShape.slashed.regex.hasMatch('01/09/2026'), isTrue);
      expect(DateShape.slashed.regex.hasMatch('09/01/2026'), isTrue);
      expect(DateShape.slashed.regex.hasMatch('2026-09-01'), isFalse);
    });

    test('a setting maps to the shape it renders', () {
      expect(DateShape.of('yyyy-MM-dd'), DateShape.iso);
      expect(DateShape.of('dd-MM-yyyy'), DateShape.dashed);
      expect(DateShape.of('dd/MM/yyyy'), DateShape.slashed);
      expect(DateShape.of('MM/dd/yyyy'), DateShape.slashed);
    });
  });

  group('real POS text is not mistaken for a date', () {
    // 🚨 Every one of these appears on the screens `14` reads. A false positive
    // here fails a correct screen, and the usual response to a test that fails
    // on correct code is to stop believing it.
    const notDates = <String, String>{
      'a document number': 'POS1-200-000001',
      'an EAN-13 barcode': '2000000001616',
      'a product code': 'P090613440',
      'a price': '18.00',
      'a total with currency': '140.00 DH',
      'a time on its own': '23:42',
      'a tax number': 'TAX331694774',
      'a phone number': '+212609061440',
      'a run tag': '[E2E 09061344]',
      'a quantity': '1.234',
      'a percentage': '20.0%',
    };

    for (final entry in notDates.entries) {
      test('${entry.key} (${entry.value})', () {
        for (final shape in DateShape.values) {
          expect(
            shape.regex.hasMatch(entry.value),
            isFalse,
            reason: '${entry.value} was read as a ${shape.name} date.',
          );
        }
      });
    }
  });

  group('against a real screen dump', () {
    // `visibleTexts` joins every Text on screen with " | ", so the regexes run
    // over one long concatenation — word boundaries have to survive that.
    const isoScreen =
        'Sales History | Date | 2026-09-01 23:42 | Créé | 2026-09-01 23:40 | '
        'POS1-200-000001 | 140.00 DH | Walk-in Customer | 2000000001616';

    const slashedScreen =
        'Sales History | Date | 01/09/2026 23:42 | Créé | 01/09/2026 23:40 | '
        'POS1-200-000001 | 140.00 DH | Walk-in Customer | 2000000001616';

    test('an ISO screen reads as ISO and nothing else', () {
      expect(DateShape.iso.regex.allMatches(isoScreen), hasLength(2));
      expect(DateShape.slashed.regex.hasMatch(isoScreen), isFalse);
      expect(DateShape.dashed.regex.hasMatch(isoScreen), isFalse);
    });

    test('a slashed screen reads as slashed and nothing else', () {
      expect(DateShape.slashed.regex.allMatches(slashedScreen), hasLength(2));
      expect(DateShape.iso.regex.hasMatch(slashedScreen), isFalse);
      expect(DateShape.dashed.regex.hasMatch(slashedScreen), isFalse);
    });

    test('a HALF-MIGRATED screen is caught', () {
      // The state that actually shipped: one column fixed, another still
      // building its date by hand. Both shapes present at once.
      const mixed =
          'Date | 2026-09-01 23:42 | Créé | 01/09/2026 23:40 | POS1-200-000001';

      expect(DateShape.iso.regex.hasMatch(mixed), isTrue);
      expect(
        DateShape.slashed.regex.hasMatch(mixed),
        isTrue,
        reason: 'This is the whole point: a stray hand-rolled date beside a '
            'correct one has to be visible, or the test passes on the bug.',
      );
    });
  });
}
