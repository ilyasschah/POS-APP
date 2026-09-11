// A tax marked Fixed is a flat amount per unit — its rate times the quantity —
// never a percentage. Before 2026-09-11 the document editor priced every tax as
// `price × (1 + rate / 100)`, so a 2.00 levy on a 50.00 line read as 2%, and the
// catalogue import matched taxes on the number alone.

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/cart/checkout_models.dart';
import 'package:pos_app/database/app_database.dart';
import 'package:pos_app/document/document_model.dart';
import 'package:pos_app/product/catalog_transfer.dart';

void main() {
  group('discountableUnitPrice (POS item discounts and promotions)', () {
    CartItem soda({required bool inclusive}) => CartItem(
          cartItemId: 'soda',
          posOrderId: 0,
          productId: 1,
          price: 52,
          productName: 'Soda',
          isTaxInclusive: inclusive,
          appliedTaxes: [
            MenuTax(id: 7, name: 'Eco fee', rate: 2, isFixed: true, isTaxOnTotal: false),
          ],
        );

    test('an inclusive price leaves its fixed tax out of the % base', () {
      final item = soda(inclusive: true);
      expect(discountableUnitPrice(item), 50);
      // 10% off is 5.00, never 5.20: the fixed 2.00 is not discounted.
      expect(discountableUnitPrice(item) * 10 / 100, 5);
    });

    test('an exclusive price never contained it, so it is the price', () {
      expect(discountableUnitPrice(soda(inclusive: false)), 52);
    });

    test('a percentage tax stays inside the base', () {
      final item = CartItem(
        cartItemId: 'tea',
        posOrderId: 0,
        productId: 2,
        price: 60,
        productName: 'Tea',
        appliedTaxes: [
          MenuTax(id: 8, name: 'VAT', rate: 20, isFixed: false, isTaxOnTotal: false),
        ],
      );
      expect(discountableUnitPrice(item), 60);
    });
  });

  group('editorLineMoney', () {
    test('a fixed tax is added per unit, not multiplied in', () {
      final m = editorLineMoney(
        priceBeforeTax: 50,
        quantity: 10,
        discount: 0,
        discountType: 0,
        taxRate: 2,
        taxIsFixed: true,
      );
      expect(m.unitPrice, 52);
      expect(m.total, 520);
    });

    test('a percentage tax is unchanged', () {
      final m = editorLineMoney(
        priceBeforeTax: 50,
        quantity: 10,
        discount: 0,
        discountType: 0,
        taxRate: 20,
        taxIsFixed: false,
      );
      expect(m.unitPrice, 60);
      expect(m.total, 600);
    });

    test('a percentage discount never shrinks a fixed tax', () {
      final m = editorLineMoney(
        priceBeforeTax: 50,
        quantity: 10,
        discount: 10,
        discountType: 0,
        taxRate: 2,
        taxIsFixed: true,
      );
      expect(m.unitDiscount, 5);
      expect(m.total, 470);
    });
  });

  group('DocumentItem.fromDrift', () {
    // A manual editor line (tax-inclusive `total`): 10 × 50.00 plus a fixed 2.00.
    const row = DocumentItemsTableData(
      localId: 'line',
      documentId: 'doc',
      productId: 1,
      quantity: 10,
      unitPrice: 52,
      priceBeforeTax: 50,
      discount: 0,
      discountType: 0,
      total: 520,
      taxAmount: 20,
      taxId: 7,
      taxRate: 2,
      syncStatus: 'synced',
    );

    DocumentItem read(Set<int> fixedTaxIds) => DocumentItem.fromDrift(
          row,
          isCheckoutDoc: false,
          companyId: 1,
          documentId: 1,
          fixedTaxIds: fixedTaxIds,
        );

    test('a fixed tax is subtracted from the total, not divided out', () {
      final item = read({7});
      expect(item.taxIsFixed, isTrue);
      expect(item.priceBeforeTaxAfterDiscount, 500);
      expect(item.taxRateLabel, '2.00');
    });

    test('a percentage tax still reads as a rate', () {
      final item = read(const {});
      expect(item.taxIsFixed, isFalse);
      expect(item.taxRateLabel, '2%');
    });
  });

  group('catalogue import', () {
    test('the XML import carries the tax kind', () {
      const xml = '''
<?xml version="1.0"?>
<ArrayOfPosItem xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <Items>
    <PosItem xsi:type="Product">
      <Name>Soda</Name>
      <Taxes>
        <Tax><Name>Eco fee</Name><Rate>5</Rate><IsFixed>true</IsFixed></Tax>
      </Taxes>
    </PosItem>
  </Items>
</ArrayOfPosItem>''';

      final row = parseProductsXml(xml).single;
      expect(row['taxRate'], 5);
      expect(row['taxIsFixed'], isTrue);
    });

    test("the CSV export's tax-kind column is matched on import", () {
      final mapping = autoMapColumns(productCsvHeaders, productImportFields);
      expect(mapping['taxIsFixed'], productCsvHeaders.indexOf('TaxIsFixed'));
      expect(mapping['taxRate'], productCsvHeaders.indexOf('Tax'));
    });
  });
}
