import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:octopus_dashboard_web/models/unit_of_measure.dart';

/// The dashboard's unit catalogue is a COPY of the POS's. This reads the POS
/// file and fails the moment the two disagree — a new unit, a renumbered id, a
/// changed code or precision — instead of the owner reading "12 kg" for what
/// the till calls 12 lb.
void main() {
  final source = File('../Front-End/lib/uom/unit_of_measure.dart');

  test(
    'matches Front-End/lib/uom/unit_of_measure.dart unit for unit',
    () {
      final text = source.readAsStringSync();

      final constants = {
        for (final m in RegExp(r'const int (kUom\w+) = (\d+);').allMatches(text))
          m.group(1)!: int.parse(m.group(2)!),
      };
      int idOf(String token) => int.tryParse(token) ?? constants[token]!;

      final pos = [
        for (final m in RegExp(
          r"UnitOfMeasure\(id: (\w+), code: '([^']+)', category: UomCategory\.(\w+), "
          r'factor: ([^,]+), rounding: [^,]+, digits: (\d+)\)',
        ).allMatches(text))
          (
            id: idOf(m.group(1)!),
            code: m.group(2)!,
            category: m.group(3)!,
            isReference: double.tryParse(m.group(4)!.trim()) == 1,
            digits: int.parse(m.group(5)!),
          ),
      ];
      expect(pos, isNotEmpty, reason: 'the POS catalogue could not be parsed');

      final mine = [
        for (final u in kUnitsOfMeasure)
          (
            id: u.id,
            code: u.code,
            category: u.category.name,
            isReference: u.isReference,
            digits: u.digits,
          ),
      ];
      expect(mine, pos);
    },
    skip: source.existsSync() ? false : 'the POS sources are not checked out beside this app',
  );
}
