// Pins POS feedback sounds (handoff.md ⭐10), which did not exist at all — no
// setting, no asset, no call site.
//
// Playback itself needs an audio device, so what is pinned is the decision
// layer: whether a given event is audible, at what volume, and that a muted or
// misconfigured till degrades to silence instead of throwing on a hot path.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/core/sound_service.dart';

void main() {
  group('shouldPlaySound', () {
    test('an empty map falls back to the shipped defaults', () {
      // Scan feedback is the one a head-down cashier depends on, so it is on
      // out of the box; the error tone is not (it would fire on every
      // validation toast).
      expect(shouldPlaySound(const {}, PosSound.scanOk), isTrue);
      expect(shouldPlaySound(const {}, PosSound.scanFail), isTrue);
      expect(shouldPlaySound(const {}, PosSound.checkout), isTrue);
      expect(shouldPlaySound(const {}, PosSound.error), isFalse);
    });

    test('the master switch silences everything', () {
      final settings = {
        SettingKeys.soundsEnabled: 'false',
        SettingKeys.soundScanOk: 'true',
        SettingKeys.soundCheckout: 'true',
      };
      for (final sound in PosSound.values) {
        expect(shouldPlaySound(settings, sound), isFalse, reason: sound.name);
      }
    });

    test('events are independent — keep the scan beep, drop the rest', () {
      final settings = {
        SettingKeys.soundsEnabled: 'true',
        SettingKeys.soundScanOk: 'true',
        SettingKeys.soundScanFail: 'true',
        SettingKeys.soundCheckout: 'false',
        SettingKeys.soundError: 'false',
      };
      expect(shouldPlaySound(settings, PosSound.scanOk), isTrue);
      expect(shouldPlaySound(settings, PosSound.scanFail), isTrue);
      expect(shouldPlaySound(settings, PosSound.checkout), isFalse);
      expect(shouldPlaySound(settings, PosSound.error), isFalse);
    });

    test('stored values are read case- and whitespace-insensitively', () {
      expect(
        shouldPlaySound({SettingKeys.soundsEnabled: ' TRUE '}, PosSound.scanOk),
        isTrue,
      );
    });
  });

  group('soundVolume', () {
    test('defaults to 70%', () {
      expect(soundVolume(const {}), closeTo(0.70, 1e-9));
    });

    test('maps 0-100 onto 0.0-1.0', () {
      expect(soundVolume({SettingKeys.soundVolume: '0'}), 0.0);
      expect(soundVolume({SettingKeys.soundVolume: '100'}), 1.0);
      expect(soundVolume({SettingKeys.soundVolume: '50'}), closeTo(0.5, 1e-9));
    });

    test('clamps and survives junk rather than throwing at the till', () {
      expect(soundVolume({SettingKeys.soundVolume: '500'}), 1.0);
      expect(soundVolume({SettingKeys.soundVolume: '-20'}), 0.0);
      expect(soundVolume({SettingKeys.soundVolume: 'loud'}), closeTo(0.7, 1e-9));
      expect(soundVolume({SettingKeys.soundVolume: ''}), closeTo(0.7, 1e-9));
    });
  });

  group('SoundService.play', () {
    late List<(PosSound, double)> played;

    setUp(() {
      played = [];
      SoundService.testHook = (sound, volume) async {
        played.add((sound, volume));
      };
    });

    tearDown(() => SoundService.testHook = null);

    test('plays an enabled event at the configured volume', () {
      SoundService.instance.play(
        {SettingKeys.soundsEnabled: 'true', SettingKeys.soundVolume: '40'},
        PosSound.scanOk,
      );
      expect(played, hasLength(1));
      expect(played.single.$1, PosSound.scanOk);
      expect(played.single.$2, closeTo(0.4, 1e-9));
    });

    test('a disabled event is not played', () {
      SoundService.instance.play(
        {SettingKeys.soundsEnabled: 'false'},
        PosSound.checkout,
      );
      expect(played, isEmpty);
    });

    test('volume 0 short-circuits — no player is opened to play silence', () {
      SoundService.instance.play(
        {SettingKeys.soundsEnabled: 'true', SettingKeys.soundVolume: '0'},
        PosSound.checkout,
      );
      expect(played, isEmpty);
    });
  });

  group('assets and keys line up', () {
    test('every event names a distinct asset and a distinct setting', () {
      final assets = PosSound.values.map((s) => s.asset).toSet();
      final keys = PosSound.values.map((s) => s.settingKey).toSet();
      expect(assets, hasLength(PosSound.values.length));
      expect(keys, hasLength(PosSound.values.length));
    });

    test('every per-event setting has a shipped default', () {
      for (final sound in PosSound.values) {
        expect(kSettingDefaults[sound.settingKey], isNotNull,
            reason: sound.settingKey);
      }
      expect(kSettingDefaults[SettingKeys.soundsEnabled], 'true');
      expect(kSettingDefaults[SettingKeys.soundVolume], '70');
    });
  });
}
