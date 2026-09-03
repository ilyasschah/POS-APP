import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:kitchen_display/kds_locale.dart';
import 'package:kitchen_display/kds_models.dart';
import 'package:kitchen_display/l10n/kds_localizations.dart';

/// Replaces the generated `widget_test.dart`, which pumped `KitchenDisplayApp`
/// and asserted a counter incremented — the Flutter scaffold's own test, left
/// untouched. There is no counter in a kitchen display, so it could never have
/// passed; it only went unnoticed because no workflow ran it.
///
/// Pumping the real app is not the replacement: `RootScreen.initState` boots the
/// LAN server and touches storage, so a widget test would bind a socket on the
/// runner. The parsing in `kds_models.dart` is where the actual risk lives — it
/// is the wire contract between a POS and a display that may be on different
/// versions — and it is pure, so it tests cleanly.
void main() {
  group('KitchenItem.fromJson', () {
    test('reads productName, and falls back to name for an older POS', () {
      expect(
        KitchenItem.fromJson({'id': 1, 'productName': 'Steak'}).name,
        'Steak',
      );
      expect(KitchenItem.fromJson({'id': 1, 'name': 'Steak'}).name, 'Steak');
    });

    test('a missing product name parses as empty, never as a placeholder', () {
      // 🚨 It used to parse as the literal 'Unknown Item'. That stopped being
      // right when the display gained languages: `fromJson` runs on data that
      // `toJson` writes straight back into the stored snapshot, so a translated
      // placeholder here would freeze whatever language was showing at parse
      // time into storage and the card would then contradict the picker. The
      // screen substitutes `unknownItem` at DISPLAY time instead.
      expect(KitchenItem.fromJson({'id': 1}).name, '');
    });

    test('defaults quantity to 1 and widens an int to double', () {
      expect(KitchenItem.fromJson({'id': 1}).quantity, 1.0);
      expect(KitchenItem.fromJson({'id': 1, 'quantity': 3}).quantity, 3.0);
      expect(KitchenItem.fromJson({'id': 1, 'quantity': 1.5}).quantity, 1.5);
    });

    test('keeps modifier names, trimmed', () {
      final item = KitchenItem.fromJson({
        'id': 1,
        'modifiers': ['  Extra Cheese  ', 'No Sugar'],
      });
      expect(item.modifiers, ['Extra Cheese', 'No Sugar']);
    });

    test('drops blank and non-string modifiers instead of showing junk', () {
      final item = KitchenItem.fromJson({
        'id': 1,
        'modifiers': ['Extra Cheese', '', '   ', 42, null],
      });
      expect(item.modifiers, ['Extra Cheese']);
    });

    test('a POS predating modifiers yields an empty list, not a crash', () {
      expect(KitchenItem.fromJson({'id': 1}).modifiers, isEmpty);
    });
  });

  group('KitchenOrder.fromJson', () {
    test('prefers orderRef but accepts a legacy id as the echo key', () {
      expect(
        KitchenOrder.fromJson({'orderRef': 'abc', 'id': 9}).orderRef,
        'abc',
      );
      expect(KitchenOrder.fromJson({'id': 9}).orderRef, '9');
      expect(KitchenOrder.fromJson({}).orderRef, '');
    });

    test('accepts serviceType in either casing', () {
      expect(KitchenOrder.fromJson({'serviceType': 2}).serviceType, 2);
      expect(KitchenOrder.fromJson({'ServiceType': 3}).serviceType, 3);
      expect(KitchenOrder.fromJson({}).serviceType, 1);
    });

    test('parses nested items', () {
      final order = KitchenOrder.fromJson({
        'orderRef': 'o1',
        'items': [
          {'id': 1, 'productName': 'Fries', 'quantity': 2},
          {'id': 2, 'productName': 'Coke'},
        ],
      });
      expect(order.items, hasLength(2));
      expect(order.items.first.name, 'Fries');
      expect(order.items.first.quantity, 2.0);
    });

    test('an order with no items parses to an empty ticket', () {
      expect(KitchenOrder.fromJson({'orderRef': 'o1'}).items, isEmpty);
    });

    test('an unparseable date leaves dateCreated null rather than throwing', () {
      expect(
        KitchenOrder.fromJson({'orderRef': 'o1', 'dateCreated': 'not-a-date'})
            .dateCreated,
        isNull,
      );
    });
  });

  group('KitchenOrder.typeString', () {
    String typeFor(int t, String language) => KitchenOrder.fromJson(
        {'serviceType': t}).typeString(lookupKdsLocalizations(Locale(language)));

    test('maps the known service types', () {
      expect(typeFor(1, 'en'), 'Dine in');
      expect(typeFor(2, 'en'), 'Takeaway');
      expect(typeFor(3, 'en'), 'Delivery');
    });

    test('falls back for an unknown type', () {
      expect(typeFor(99, 'en'), 'Order');
    });

    // The point of the localization pass: the cook reads the ticket, and the
    // service type is the line that says what to DO with the food.
    test('every service type is translated in every shipped language', () {
      for (final language in kKdsLanguages) {
        for (final type in [1, 2, 3, 99]) {
          final text = typeFor(type, language);
          expect(text, isNotEmpty,
              reason: '$language has no string for serviceType $type');
          if (language != 'en') {
            expect(text, isNot(typeFor(type, 'en')),
                reason: '$language still shows the English text for '
                    'serviceType $type');
          }
        }
      }
    });
  });

  group('resolveKdsLocale — the Arabic-fallback guard', () {
    // 🚨 gen-l10n emits supportedLocales ALPHABETICALLY, so `ar` is first, and
    // Flutter falls back to the first entry for anything it cannot resolve.
    // Without this guard an unset or stale preference renders the whole kitchen
    // display in Arabic instead of English. Deleting it as redundant is exactly
    // the mistake it exists to prevent — so it is pinned here.
    test('null and empty fall back to English, never to the first locale', () {
      expect(resolveKdsLocale(null).languageCode, 'en');
      expect(resolveKdsLocale('').languageCode, 'en');
      expect(resolveKdsLocale('   ').languageCode, 'en');
    });

    test('an unsupported language falls back to English', () {
      expect(resolveKdsLocale('de').languageCode, 'en');
      expect(resolveKdsLocale('es').languageCode, 'en');
    });

    test('the shipped languages pass through', () {
      for (final code in kKdsLanguages) {
        expect(resolveKdsLocale(code).languageCode, code);
      }
    });

    test('a region tag keeps its language rather than dropping to English', () {
      expect(resolveKdsLocale('ar_MA').languageCode, 'ar');
      expect(resolveKdsLocale('fr-CA').languageCode, 'fr');
      expect(resolveKdsLocale('AR').languageCode, 'ar');
    });

    test('the first supported locale really is the one that would bite', () {
      // If this ever stops being `ar`, the guard is still correct — but the
      // comment explaining WHY it exists would be stale, so fail loudly.
      expect(KdsLocalizations.supportedLocales.first.languageCode, 'ar');
    });
  });

  group('KitchenOrder.headerColor', () {
    KitchenOrder agedMinutes(int minutes) => KitchenOrder.fromJson({
          'orderRef': 'o1',
          'dateCreated': DateTime.now()
              .subtract(Duration(minutes: minutes))
              .toIso8601String(),
        });

    const fresh = 0xFFAED581;
    const warning = 0xFFFFF176;
    const overdue = 0xFFFF8A65;

    test('a fresh ticket is green', () {
      expect(agedMinutes(1).headerColor.toARGB32(), fresh);
    });

    test('past five minutes it turns yellow', () {
      expect(agedMinutes(6).headerColor.toARGB32(), warning);
    });

    test('past fifteen minutes it turns orange', () {
      expect(agedMinutes(16).headerColor.toARGB32(), overdue);
    });

    test('an undated ticket is treated as fresh, not as overdue', () {
      expect(
        KitchenOrder.fromJson({'orderRef': 'o1'}).headerColor.toARGB32(),
        fresh,
      );
    });
  });

  group('round trip', () {
    test('toJson output parses back to the same ticket', () {
      final original = KitchenOrder.fromJson({
        'orderRef': 'o-42',
        'number': 'A17',
        'tableName': 'T3',
        'serviceType': 2,
        'serviceStatus': 2,
        'items': [
          {
            'id': 1,
            'productName': 'Burger',
            'quantity': 2,
            'comment': 'well done',
            'modifiers': ['No Onion'],
          },
        ],
      });

      final restored = KitchenOrder.fromJson(original.toJson());

      expect(restored.orderRef, original.orderRef);
      expect(restored.number, original.number);
      expect(restored.tableName, original.tableName);
      expect(restored.serviceType, original.serviceType);
      expect(restored.items.single.name, 'Burger');
      expect(restored.items.single.quantity, 2.0);
      expect(restored.items.single.comment, 'well done');
      expect(restored.items.single.modifiers, ['No Onion']);
    });
  });
}
