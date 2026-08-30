// ignore_for_file: avoid_print
//
// Rings a sale onto a real pole display, composing every frame with the SAME
// code the till uses (`pole_display_frame.dart`) — so what appears here is what
// a customer would read.
//
//   .\tool\pole_display_listener.ps1 -Port COM9                  (ASCII)
//   .\tool\pole_display_listener.ps1 -Port COM9 -Charset cp1256  (Arabic)
//
//   dart run tool/probe_display.dart COM8
//   dart run tool/probe_display.dart COM8 cp1256
//   dart run tool/probe_display.dart COM8 cp1256 ar
import 'package:pos_app/utils/pole_display_frame.dart';
import 'package:pos_app/utils/windows_device_write.dart';

const width = 20;

/// The TOTAL DUE label per language. The app resolves this through
/// `AppLocalizations`; repeated here because this probe is deliberately free of
/// Flutter so it can run under a bare `dart run`.
const totalDueByLang = {
  'en': 'TOTAL DUE',
  'fr': 'TOTAL A PAYER',
  'ar': 'المبلغ المستحق',
};
const welcomeByLang = {
  'en': 'WELCOME!',
  'fr': 'BIENVENUE !',
  'ar': 'أهلا وسهلا',
};

late DisplayCharset charset;

Future<void> beat(String port, String line1, String line2) async {
  final lines = poleDisplayLines(
    line1: line1,
    line2: line2,
    width: width,
    charset: charset,
  );
  print('  |${lines.line1}|');
  print('  |${lines.line2}|');
  print('');
  writeToWindowsDevice(
    devicePath: windowsDevicePath(port),
    bytes: poleDisplayFrame(
      line1: line1,
      line2: line2,
      width: width,
      charset: charset,
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 1200));
}

Future<void> item(
  String port,
  String name,
  double qty,
  double price,
  double total, {
  String unit = '',
}) =>
    beat(
      port,
      name,
      lineItemRow(
        quantity: qty,
        unitPrice: price,
        runningTotal: total,
        width: width,
        unitLabel: unit,
      ),
    );

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 'COM1' : args.first.toUpperCase();
  charset =
      DisplayCharset.fromSetting(args.length > 1 ? args[1] : 'ascii');
  final lang = args.length > 2 ? args[2] : 'en';

  print('port    : $port');
  print('charset : ${charset.settingValue}');
  print('language: $lang\n');

  try {
    await beat(port, welcomeByLang[lang] ?? welcomeByLang['en']!, '');
    await item(port, 'Cafe au lait', 2, 12.50, 25.00);
    await item(port, 'كرواسون', 1, 8.00, 33.00);
    await item(port, 'Sucre en poudre', 0.125, 50.00, 39.25, unit: 'kg');
    await item(port, 'Thé à la Menthe', 1, 6.00, 45.25);
    await beat(port, totalDueByLang[lang] ?? totalDueByLang['en']!,
        'MAD 45.25');
    await beat(port, welcomeByLang[lang] ?? welcomeByLang['en']!, '');
    print('done - seven frames sent.');
  } on WindowsDeviceException catch (e) {
    print('FAILED: ${e.message}  (code ${e.errorCode})');
  }
}
