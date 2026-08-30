// ignore_for_file: avoid_print
//
// Prints what `utils/windows_ports.dart` sees on THIS machine.
// Run:  dart run tool/probe_ports.dart
import 'package:pos_app/utils/windows_ports.dart';

void main() {
  print('SERIALCOMM      : ${WindowsPorts.serial()}');
  print('PARALLEL PORTS  : ${WindowsPorts.parallel()}');
  print('merged          : ${mergePortLists(detected: [
        WindowsPorts.serial(),
        WindowsPorts.parallel()
      ])}');
  print('merged + saved  : ${mergePortLists(detected: [
        WindowsPorts.serial(),
        WindowsPorts.parallel()
      ], saved: 'COM7')}');
}
