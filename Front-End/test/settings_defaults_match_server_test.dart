// The till's default for a setting must be the server's default for it.
//
// Two lists decide what a setting is when nobody has changed it:
//
//  • `CompanyDefaultsSeeder.DefaultProperties` on the server — the row every new
//    company is created with, and (since 2026-09-10) the row every existing
//    company is backfilled with at startup.
//  • `kSettingDefaults` on the till — what it assumes when the server has not
//    sent a row.
//
// They had drifted apart on 43 keys. That was not cosmetic: a company created
// before a key existed had no row for it, so it ran on the TILL's value, while a
// newer company ran on the server's. The same setting behaved differently by
// creation date — `Order.PreventNegativeInventory` true for one shop and false
// for the next, `Void.RequireReason` likewise, dates formatted in UTC instead of
// Casablanca.
//
// This test reads the server's list straight out of the C# source, so the two
// cannot drift again without the build saying so.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/app_settings/app_settings_model.dart';
import 'package:pos_app/app_settings/service_status_model.dart';
import 'package:pos_app/app_settings/service_type_model.dart';
import 'package:pos_app/settings/device_scoped_settings.dart';

const _seederPath = '../Back-End/Web-POS.Api/Services/CompanyDefaultsSeeder.cs';

/// Keys whose till default is ALLOWED to differ from the seed — each with its
/// reason, because an exception nobody can explain is just drift with a label.
const _deliberateExceptions = <String, String>{
  'Application.Language':
      'the greeting language of a terminal not yet linked to any company; '
      'every company has its own row, and that row is what governs it',
};

/// Retired on 2026-09-10: seeded, and read by nothing on either side.
const _retiredOn20260910 = [
  'App.EnableSounds',
  'Print.CashDrawer.Enabled',
  'Print.PrinterType',
  'Database.Backup.Version',
];

/// Reads a C# string literal — regular or verbatim (`@"…"`) — starting at [i].
(String, int) _readCsString(String src, int i) {
  final out = StringBuffer();
  if (src[i] == '@') {
    i += 2;
    while (true) {
      final ch = src[i];
      if (ch == '"') {
        if (src[i + 1] == '"') {
          out.write('"');
          i += 2;
          continue;
        }
        return (out.toString(), i + 1);
      }
      out.write(ch);
      i++;
    }
  }
  i++;
  while (true) {
    final ch = src[i];
    if (ch == r'\') {
      final next = src[i + 1];
      out.write(switch (next) { 'n' => '\n', 't' => '\t', _ => next });
      i += 2;
      continue;
    }
    if (ch == '"') return (out.toString(), i + 1);
    out.write(ch);
    i++;
  }
}

/// The body of `<name> = { … };` in the seeder.
String _block(String src, String name) {
  final m = RegExp('$name' r'\s*=\s*\{(.*?)\n\s*\};', dotAll: true).firstMatch(src);
  expect(m, isNotNull, reason: 'Could not find $name in $_seederPath.');
  return m!.group(1)!;
}

/// True when the match sits on a line that is commented out.
bool _commentedOut(String block, int at) {
  final lineStart = block.lastIndexOf('\n', at) + 1;
  return block.substring(lineStart, at).contains('//');
}

Map<String, String> _serverDefaults(String src) {
  final block = _block(src, 'DefaultProperties');
  final result = <String, String>{};
  for (final m in RegExp(r'\(\s*"([^"]+)"\s*,\s*').allMatches(block)) {
    if (_commentedOut(block, m.start)) continue;
    final (value, _) = _readCsString(block, m.end);
    result[m.group(1)!] = value;
  }
  return result;
}

List<String> _retired(String src) {
  final block = _block(src, 'ObsoleteProperties');
  return [
    for (final m in RegExp(r'"([^"]+)"').allMatches(block))
      if (!_commentedOut(block, m.start)) m.group(1)!,
  ];
}

void main() {
  late final Map<String, String> server;
  late final List<String> retired;

  setUpAll(() {
    final file = File(_seederPath);
    // Loud, not skipped: a guard that quietly stops running is worse than none,
    // because the next drift ships unnoticed.
    expect(file.existsSync(), isTrue,
        reason: 'Cannot read $_seederPath from ${Directory.current.path}. '
            'Run the tests from Front-End/ — fix the path, do not delete the test.');
    final src = file.readAsStringSync();
    server = _serverDefaults(src);
    retired = _retired(src);
  });

  test('the seeder is actually read, not assumed', () {
    // A parser that silently came back empty would make every check below pass.
    expect(server.length, greaterThan(50));
    expect(server['CurrencySymbol'], 'DH');
    // The verbatim @"…" string is the awkward one to parse.
    expect(server['Pos.BookingSettings'], contains('"resourceMode":"table"'));
    expect(retired, contains('App.IndustryMode'));
  });

  test('every company setting the server seeds has the same default on the till',
      () {
    final drift = <String>[];
    server.forEach((key, serverValue) {
      if (DeviceScopedSettings.isDeviceScoped(key)) return; // per terminal
      if (_deliberateExceptions.containsKey(key)) return;
      if (!kSettingDefaults.containsKey(key)) return;
      final tillValue = kSettingDefaults[key];
      if (tillValue != serverValue) {
        drift.add('$key: server "$serverValue" / till "$tillValue"');
      }
    });

    expect(drift, isEmpty,
        reason: 'The till would assume one value and the server seed another. '
            'Make kSettingDefaults match CompanyDefaultsSeeder.DefaultProperties, '
            'or — only with a reason — add the key to _deliberateExceptions:\n  '
            '${drift.join('\n  ')}');
  });

  test('each deliberate exception still differs — or it is not an exception', () {
    // Stops the allow-list outliving its reason: if the two ever converge, the
    // entry is just a hole in the guard.
    for (final key in _deliberateExceptions.keys) {
      expect(server.containsKey(key), isTrue, reason: '$key is no longer seeded');
      expect(kSettingDefaults[key], isNot(server[key]),
          reason: '$key agrees on both sides now — remove it from '
              '_deliberateExceptions.');
    }
  });

  test('a retired setting keeps no default on the till', () {
    final lingering = retired.where(kSettingDefaults.containsKey).toList();

    expect(lingering, isEmpty,
        reason: 'The server sweeps these rows; a default on the till keeps '
            'the setting alive in every screen that reads it: $lingering');
  });

  test('the four keys retired on 2026-09-10 are gone from both sides', () {
    for (final key in _retiredOn20260910) {
      expect(server.containsKey(key), isFalse, reason: '$key is still seeded');
      expect(retired, contains(key), reason: '$key is not swept');
      expect(kSettingDefaults.containsKey(key), isFalse,
          reason: '$key still has a default on the till');
    }
  });

  test('the fallback lists in code say the same as the defaults map', () {
    // The till keeps a SECOND copy of these two defaults: the list a venue
    // falls back to when its own JSON cannot be parsed. Aligning only the map
    // would leave a till that shows TALABIA normally and ORDER after one bad
    // write. Compared as decoded JSON, so key order and spacing do not matter.
    expect(
      jsonDecode(CustomServiceType.listToJson(CustomServiceType.defaults)),
      jsonDecode(kSettingDefaults[SettingKeys.customServiceTypes]!),
    );
    expect(
      jsonDecode(CustomServiceStatus.listToJson(CustomServiceStatus.defaults)),
      jsonDecode(kSettingDefaults[SettingKeys.customServiceStatuses]!),
    );
  });
}
