// The document editor's rules, without a widget in sight: what a line costs,
// what each wizard step still needs, what is sent to create or update a
// document — and that a save interrupted half way can be run again without
// sending anything twice.
import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_dashboard_web/api/api_exception.dart';
import 'package:octopus_dashboard_web/features/documents/document_draft.dart';
import 'package:octopus_dashboard_web/features/documents/documents_controller.dart';
import 'package:octopus_dashboard_web/models/document_lookups.dart';
import 'package:octopus_dashboard_web/models/product.dart';

import 'fake_api.dart';

const purchase = DocumentTypeOption(
  id: 1,
  name: 'Purchase',
  code: '100',
  categoryId: 1,
  categoryName: 'Expenses',
  stockDirection: 1,
);
const vat = TaxOption(id: 1, name: 'VAT', rate: 20);
const levy = TaxOption(id: 2, name: 'Eco levy', rate: 2, isFixed: true);

Product product({int uomId = 1, double? packSize}) => Product(
  id: 7,
  name: 'Pepsi',
  code: null,
  price: 10,
  cost: 5,
  isTaxInclusivePrice: true,
  isPriceChangeAllowed: false,
  isService: false,
  isUsingDefaultQuantity: true,
  isEnabled: true,
  color: 'Transparent',
  uomId: uomId,
  packSize: packSize,
);

DraftLine line({
  double quantity = 2,
  double price = 10,
  TaxOption? tax,
  double discount = 0,
  int discountType = DiscountKind.percent,
  int? serverId,
  int? pushedTaxId,
}) => DraftLine(
  serverId: serverId,
  productId: 7,
  productName: 'Pepsi',
  quantity: quantity,
  priceBeforeTax: price,
  tax: tax,
  discount: discount,
  discountType: discountType,
  pushedTaxId: pushedTaxId,
);

/// A draft every step of which is complete.
DocumentDraft ready({List<DraftLine>? lines}) =>
    DocumentDraft.blank(DateTime(2026, 9, 15, 10, 30)).copyWith(
      type: purchase,
      number: '26-100-000001',
      customerId: 2,
      userId: 9,
      warehouseId: 17,
      lines: lines ?? [line()],
    );

void main() {
  group('line money', () {
    test('a percentage tax is multiplied into the price', () {
      final money = lineMoney(
        priceBeforeTax: 10,
        quantity: 3,
        discount: 0,
        discountType: DiscountKind.percent,
        tax: vat,
      );
      expect(money.unitPrice, closeTo(12, 1e-9));
      expect(money.total, closeTo(36, 1e-9));
    });

    test('a fixed tax is added per unit, and a percentage discount never '
        'shrinks it', () {
      final money = lineMoney(
        priceBeforeTax: 10,
        quantity: 10,
        discount: 10,
        discountType: DiscountKind.percent,
        tax: levy,
      );
      expect(money.unitPrice, 12);
      // 10% of the 10.00 price, not of the 12.00 with the levy in it.
      expect(money.unitDiscount, closeTo(1, 1e-9));
      expect(money.total, closeTo(110, 1e-9));
    });

    test('an amount discount comes off each unit', () {
      final money = lineMoney(
        priceBeforeTax: 10,
        quantity: 2,
        discount: 1.5,
        discountType: DiscountKind.amount,
      );
      expect(money.total, closeTo(17, 1e-9));
    });
  });

  group('stock in the product unit', () {
    test('kilograms of stock read as grams for a gram-priced product', () {
      expect(stockInProductUnit(0.25, product(uomId: 11)), 250);
    });

    test('pieces read as boxes of the product\'s own pack size', () {
      expect(stockInProductUnit(48, product(uomId: 3, packSize: 24)), 2);
    });

    test('a box with no pack size is the nominal dozen', () {
      expect(stockInProductUnit(24, product(uomId: 3)), 2);
    });
  });

  group('the draft', () {
    test('a percentage document discount comes off the lines total', () {
      final draft = ready(lines: [line(quantity: 10)]).copyWith(discount: 10);
      expect(draft.subtotal, 100);
      expect(draft.discountAmount, 10);
      expect(draft.total, 90);
    });

    test('an amount discount never takes the total below zero', () {
      final draft = ready(
        lines: [line(quantity: 1)],
      ).copyWith(discount: 50, discountType: DiscountKind.amount);
      expect(draft.total, 0);
    });

    test('each step says what it still needs', () {
      final blank = DocumentDraft.blank(DateTime(2026, 9, 15));
      expect(
        blank.problemAt(DocumentStep.type, creating: true),
        'Pick the kind of document to create.',
      );

      final typed = blank.copyWith(type: purchase);
      expect(typed.problemAt(DocumentStep.type, creating: true), isNull);
      expect(
        typed.problemAt(DocumentStep.details, creating: true),
        'Give the document a number.',
      );
      expect(
        typed.copyWith(number: 'X').problemAt(DocumentStep.parties, creating: true),
        'Choose the supplier.',
      );
      expect(
        ready(lines: []).problemAt(DocumentStep.lines, creating: true),
        'Add at least one line.',
      );
      // An existing document may be left with no lines while it is edited.
      expect(
        ready(lines: []).problemAt(DocumentStep.lines, creating: false),
        isNull,
      );
      expect(ready().firstProblem(creating: true), isNull);
    });

    test('a due date before the document date is caught on its step', () {
      final draft = ready().copyWith(dueDate: DateTime(2026, 9, 1));
      expect(
        draft.firstProblem(creating: true)?.$1,
        DocumentStep.details,
      );
    });

    test('the number follows the type only while it is the one filled in', () {
      final draft = ready().copyWith(autoNumber: '26-100-000001');
      expect(draft.numberFollowsType, isTrue);
      expect(draft.copyWith(number: 'MY-7').numberFollowsType, isFalse);
    });

    test('a hand-made document is created with no order number, and its '
        'days sent as days', () {
      final json = ready().createJson();
      expect(json['orderNumber'], isNull);
      expect(json['date'], '2026-09-15');
      expect(json['dueDate'], '2026-10-15');
      expect(json['documentTypeId'], 1);
      expect(json['total'], 20);
    });

    test('a line expects what it carries, unless it is a count', () {
      expect(line(quantity: 4).toCreateJson(99)['expectedQuantity'], 4);
      expect(
        line(quantity: 4).copyWith(expectedQuantity: 6.0).toCreateJson(99)['expectedQuantity'],
        6,
      );
      expect(line(tax: vat).toCreateJson(99)['price'], closeTo(12, 1e-9));
    });
  });

  group('saving', () {
    test('creates the header, then each line and its tax, then the total', () async {
      final api = FakeApi();

      final saved = await DocumentSaver(api).save(
        ready(lines: [line(tax: vat)]),
        onProgress: (_, _) {},
      );

      expect(api.createdDocuments, hasLength(1));
      expect(api.addedItems.single['documentId'], saved.id);
      expect(api.addedItemTaxes.single, (saved.lines.single.serverId, vat.id));
      expect(api.updatedDocuments.last['id'], saved.id);
      expect(api.updatedDocuments.last['total'], closeTo(24, 1e-9));
    });

    test('a second attempt after a failure sends nothing twice', () async {
      final api = FakeApi()
        ..failOnce['addDocumentItem:2'] = const ApiException('Out of stock');
      var draft = ready(lines: [line(), line(quantity: 5)]);
      DocumentDraft? server;
      void track(DocumentDraft d, DocumentDraft s) {
        draft = d;
        server = s;
      }

      await expectLater(
        DocumentSaver(api).save(draft, onProgress: track),
        throwsA(isA<ApiException>()),
      );
      expect(api.createdDocuments, hasLength(1));
      expect(api.addedItems, hasLength(1));

      await DocumentSaver(api).save(draft, server: server, onProgress: track);

      expect(api.createdDocuments, hasLength(1), reason: 'the header exists');
      expect(api.addedItems, hasLength(2), reason: 'only the missing line');
    });

    test('editing removes, changes and re-taxes only what changed', () async {
      final api = FakeApi();
      final kept = line(serverId: 57);
      final changed = line(serverId: 58, quantity: 3, tax: vat, pushedTaxId: vat.id);
      final removed = line(serverId: 59);
      final loaded = ready(lines: [kept, changed, removed]).copyWith(id: 56);
      final edited = loaded.copyWith(
        lines: [kept, changed.copyWith(quantity: 4)],
      );

      await DocumentSaver(api).save(edited, server: loaded, onProgress: (_, _) {});

      expect(api.createdDocuments, isEmpty);
      expect(api.addedItems, isEmpty);
      expect(api.deletedItems, [59]);
      expect(api.updatedItems.single['id'], 58);
      expect(api.updatedItems.single['quantity'], 4);
      // The tax is re-added so the server recomputes its amount for 4, not 3.
      expect(api.deletedItemTaxes, [(58, vat.id)]);
      expect(api.addedItemTaxes, [(58, vat.id)]);
    });
  });
}
