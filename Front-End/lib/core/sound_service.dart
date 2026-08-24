/// Audible feedback at the till (handoff.md ⭐10).
///
/// ## What was there before
///
/// Nothing. The backlog line records `App.EnableSounds` playing "a single
/// system click at checkout" — that setting does not exist in the codebase and
/// no call site ever played anything, on any platform. A cashier scanning items
/// head-down had no way to tell a successful read from a failed one without
/// looking up at the screen, which is the whole point of the sound.
///
/// ## The events
///
/// Four, matching the question ⭐10 asked ("scan ok / scan fail / checkout /
/// error"), each independently switchable so a venue can keep the scan beep and
/// silence the rest:
///
/// * [PosSound.scanOk] — a barcode resolved to a product and it went in the cart
/// * [PosSound.scanFail] — a barcode was claimed by a rule but matched nothing
/// * [PosSound.checkout] — a sale completed
/// * [PosSound.error] — any error toast, hooked centrally in `snackbar_helper`
///   so it covers every failure path in the app rather than a list someone has
///   to keep up to date
///
/// ## The files
///
/// `assets/sounds/*.wav` are short generated tones, not samples — so they carry
/// no licence and nothing had to be sourced before this could ship. **To use
/// your own, drop a WAV over the file of the same name and rebuild**; nothing
/// in the code names a duration or a pitch.
///
/// ## Failure policy
///
/// [SoundService.play] never throws and never awaits the caller. A missing
/// asset, a busy audio device, or a platform with no audio at all must not
/// change what the till does — a sale is not less complete because the speaker
/// is muted.
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';

/// The four moments the POS makes a sound.
enum PosSound {
  scanOk('scan_ok.wav', SettingKeys.soundScanOk),
  scanFail('scan_fail.wav', SettingKeys.soundScanFail),
  checkout('checkout.wav', SettingKeys.soundCheckout),
  error('error.wav', SettingKeys.soundError);

  const PosSound(this.asset, this.settingKey);

  /// File name under `assets/sounds/`.
  final String asset;

  /// Per-event switch. The master switch is [SettingKeys.soundsEnabled].
  final String settingKey;
}

/// Whether [sound] should be audible given the current settings.
///
/// Pure and settings-only so the decision is testable without an audio device —
/// which is the whole of the logic worth pinning here.
bool shouldPlaySound(Map<String, String> settings, PosSound sound) {
  bool on(String key) {
    final raw = settings[key] ?? kSettingDefaults[key] ?? 'true';
    return raw.trim().toLowerCase() == 'true';
  }

  return on(SettingKeys.soundsEnabled) && on(sound.settingKey);
}

/// Volume as audioplayers wants it: 0.0–1.0, clamped, from the 0–100 setting.
double soundVolume(Map<String, String> settings) {
  final raw = settings[SettingKeys.soundVolume] ??
      kSettingDefaults[SettingKeys.soundVolume] ??
      '70';
  final parsed = int.tryParse(raw.trim()) ?? 70;
  return (parsed.clamp(0, 100)) / 100.0;
}

/// Plays the POS feedback sounds.
///
/// One [AudioPlayer] per event rather than one shared player: a cashier scanning
/// quickly fires `scanOk` faster than the clip is long, and a single player
/// would cut each beep off to start the next — which sounds exactly like a
/// misread. Separate players also mean an error tone can overlap a scan tone
/// instead of replacing it.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  final Map<PosSound, AudioPlayer> _players = {};

  /// Swapped out in tests so nothing tries to open an audio device.
  static Future<void> Function(PosSound sound, double volume)? testHook;

  /// Fire-and-forget. Safe to call from a build method or a hot path.
  void play(Map<String, String> settings, PosSound sound) {
    if (!shouldPlaySound(settings, sound)) return;
    final volume = soundVolume(settings);
    if (volume <= 0) return;
    unawaited(_play(sound, volume));
  }

  Future<void> _play(PosSound sound, double volume) async {
    final hook = testHook;
    if (hook != null) {
      await hook(sound, volume);
      return;
    }
    try {
      final player = _players.putIfAbsent(sound, () => AudioPlayer());
      await player.stop();
      await player.setVolume(volume);
      await player.play(AssetSource('sounds/${sound.asset}'));
    } catch (_) {
      // Deliberately swallowed — see the failure policy above.
    }
  }

  /// Releases the players. Called when the app shuts down; harmless otherwise.
  Future<void> dispose() async {
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}
