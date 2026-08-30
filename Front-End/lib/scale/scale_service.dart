import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/app_settings_provider.dart';
import 'package:pos_app/scale/scale_weight_parser.dart';
import 'package:pos_app/utils/windows_ports.dart';

/// Whether this device can talk to a serial weighing scale at all.
///
/// `flutter_libserialport` registers an Android plugin class (so the APK still
/// builds), but reaching a scale there needs a rooted `/dev/ttyUSB*` or a USB-OTG
/// stack this app does not carry. Treat the scale as a Windows-only capability
/// and gate the UI on this — never construct [SerialScaleService] when false.
final bool kScaleSupported = Platform.isWindows;

/// Serial ports currently present on the machine (`COM1`, `COM3`, …).
///
/// Empty off Windows: enumerating would load the native library on a platform
/// where it cannot work.
///
/// Unions Windows' own device map with `libserialport`'s Ports-class walk
/// because neither is a superset of the other — see `utils/windows_ports.dart`.
/// Parallel ports are deliberately NOT included: a scale streams, and nothing
/// streams down an LPT line.
List<String> availableSerialPorts() => kScaleSupported
    ? mergePortLists(detected: [WindowsPorts.serial(), _libSerialPorts()])
    : const [];

List<String> _libSerialPorts() {
  try {
    return SerialPort.availablePorts;
  } catch (_) {
    // Native library missing or unloadable. The device map still answered.
    return const [];
  }
}

/// The scale could not be reached. Carries a message fit to show a cashier.
class ScaleException implements Exception {
  final String message;
  const ScaleException(this.message);
  @override
  String toString() => message;
}

/// Reads a continuously-streaming serial scale and emits one [ScaleReading] per
/// complete line. Construct, [start], listen to [readings], then [dispose].
class SerialScaleService {
  SerialScaleService({required this.portName, required this.baudRate});

  final String portName;
  final int baudRate;

  SerialPort? _port;
  SerialPortReader? _reader;
  StreamSubscription<Uint8List>? _sub;
  final _out = StreamController<ScaleReading>.broadcast();

  /// Holds the trailing partial line between reads — serial delivers arbitrary
  /// chunks, not whole frames.
  String _buffer = '';

  /// Bounds the buffer if a scale streams without any line terminator, so a
  /// misconfigured port can't grow memory without limit.
  static const _maxBuffer = 512;

  Stream<ScaleReading> get readings => _out.stream;

  /// Opens the port. Throws [ScaleException] if it is missing or already held by
  /// another process (the usual cause: a second POS instance, or the vendor's
  /// own scale tool still running).
  void start() {
    final port = SerialPort(portName);
    if (!port.openRead()) {
      final reason = SerialPort.lastError?.message ?? 'port unavailable';
      port.dispose();
      throw ScaleException('Could not open $portName — $reason');
    }

    final config = SerialPortConfig()
      ..baudRate = baudRate
      ..bits = 8
      ..parity = SerialPortParity.none
      ..stopBits = 1
      ..setFlowControl(SerialPortFlowControl.none);
    try {
      port.config = config;
    } finally {
      config.dispose();
    }

    _port = port;
    final reader = SerialPortReader(port);
    _reader = reader;
    _sub = reader.stream.listen(_onChunk, onError: _out.addError);
  }

  void _onChunk(Uint8List chunk) {
    _buffer += String.fromCharCodes(chunk);
    if (_buffer.length > _maxBuffer) {
      _buffer = _buffer.substring(_buffer.length - _maxBuffer);
    }

    final lines = _buffer.split(RegExp(r'[\r\n]+'));
    // The tail is whatever arrived after the last terminator — keep it for the
    // next chunk instead of parsing a half-formed frame.
    _buffer = lines.removeLast();

    for (final line in lines) {
      final reading = parseScaleWeight(line);
      if (reading != null) _out.add(reading);
    }
  }

  void dispose() {
    _sub?.cancel();
    _reader?.close();
    _port?.close();
    _port?.dispose();
    _out.close();
  }
}

/// Ports present right now. `ref.invalidate` this to rescan after the cashier
/// plugs the scale in — enumeration is a synchronous native call, so it is not
/// something to redo on every widget rebuild.
final availableSerialPortsProvider =
    Provider<List<String>>((ref) => availableSerialPorts());

/// The three `Scale.*` serial settings, narrowed so the stream below only
/// reopens the port when one of them actually changes.
typedef ScaleConfig = ({bool enabled, String port, int baudRate});

final scaleConfigProvider = Provider<ScaleConfig>((ref) {
  final enabled = ref.watch(
    appSettingsProvider.select(
      (s) => s[SettingKeys.scaleEnabled]?.toLowerCase() == 'true',
    ),
  );
  final port = ref.watch(
    appSettingsProvider.select((s) => s[SettingKeys.scalePort] ?? 'COM2'),
  );
  final baudRate = ref.watch(
    appSettingsProvider.select(
      (s) => int.tryParse(s[SettingKeys.scaleBaudRate] ?? '') ?? 9600,
    ),
  );
  return (enabled: enabled, port: port, baudRate: baudRate);
});

/// Live weight from the configured scale.
///
/// `autoDispose` is load-bearing: the port is held open only while a widget is
/// listening (i.e. the quantity keypad is on screen), so the POS never keeps a
/// COM port locked in the background.
///
/// Emits nothing when the scale is disabled or unsupported; surfaces a
/// [ScaleException] as an `AsyncError` when the port won't open.
final scaleReadingProvider = StreamProvider.autoDispose<ScaleReading>((ref) {
  final config = ref.watch(scaleConfigProvider);
  if (!kScaleSupported || !config.enabled) {
    return const Stream<ScaleReading>.empty();
  }

  final service = SerialScaleService(
    portName: config.port,
    baudRate: config.baudRate,
  );
  ref.onDispose(service.dispose);
  service.start();
  return service.readings;
});
