import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Settings that belong to **this terminal**, not to the company.
///
/// ## Why this exists
///
/// `app_properties` is cloud-synced: every row is scoped by `CompanyId` and
/// mirrored to every device in the venue. That is right for prices, taxes and
/// receipt text — and **wrong** for anything bound to the hardware or the
/// filesystem in front of the operator. A Windows POS that saves
///
/// * `Database.BackupPath = D:\POS_Backups`
/// * `Receipt.PrinterName = EPSON TM-T20II`
/// * `Scale.Port = COM2`
///
/// pushed all three to the cloud, and the Android tablet pulled them. The tablet
/// then showed a `D:\…` path it can never write, listed a printer it cannot
/// reach, and offered a COM port that does not exist on Android — the reported
/// *"the app on Android still thinks it's on a Windows PC"*, and the reason
/// backups failed there outright (`Directory('D:\\POS_Backups').createSync()`).
///
/// ## How it works
///
/// A key matching [isDeviceScoped] is read from, and written to, local
/// `SharedPreferences` only. It never reaches `/ApplicationProperties/*`, so it
/// cannot travel to another terminal, and a value another terminal already
/// pushed is shadowed by this device's own.
///
/// The cloud value remains the **fallback** when this device has never set the
/// key — so a single-terminal venue behaves exactly as before, and nothing has
/// to be re-entered after upgrading. [sanitizeInherited] is what stops an
/// inherited value being actively harmful (a Windows path on Android).
///
/// This mirrors the two overrides that already worked this way for the same
/// reason: the device name (`settings/device_identity.dart` — two terminals
/// sharing one name collide in document numbering) and the API base URL
/// (`api/api_client.dart` — you need it *before* you can sync).
class DeviceScopedSettings {
  const DeviceScopedSettings._();

  static const _prefix = 'pos.device.setting.';

  /// Exact keys that are per-terminal.
  static const Set<String> _exactKeys = {
    // How THIS terminal reaches the cloud. Cloud-syncing it is circular, and
    // actively harmful: a terminal on the LAN endpoint would push it to one on
    // the hosted endpoint, silently moving it to a different backend — a
    // failure that looks like anything except a settings problem (wrong data,
    // "subscription expired", sync that never lands).
    'Application.Api.BaseUrl',
    // Filesystem path — meaningless, and unwritable, on another OS.
    'Database.BackupPath',
    // Serial hardware. Windows-only (`kScaleSupported`), and the port number
    // differs per machine even between two Windows terminals.
    'Scale.Enabled',
    'Scale.Port',
    'Scale.BaudRate',
    'CustomerDisplay.Enabled',
    'CustomerDisplay.Port',
    'CustomerDisplay.BaudRate',
    'CustomerDisplay.DataBits',
    'CustomerDisplay.Parity',
    'CustomerDisplay.StopBits',
    'CustomerDisplay.FlowControl',
    // The KDS endpoints a terminal pushes to are a LAN concern of that
    // terminal's network, not a company-wide fact.
    'Kitchen.DisplayIps',
    // Whether THIS install polls for a new version. Per-terminal because the
    // updater only exists on Windows — cloud-syncing it would push a setting to
    // the Android tablets that they can never act on, and would let one till
    // silently turn off updating for the whole venue.
    'App.Update.AutoCheck',
    // Whether completing a sale auto-fires the station kitchen tickets. Per
    // terminal on purpose: the front till may auto-print to the kitchen while a
    // manager's tablet, sharing the same account, should not — a cloud-synced
    // value would force one choice on every device in the venue.
    'Print.AutoKitchenOnCheckout',
    // Whether completing a sale auto-prints the RECEIPT. Exactly the same
    // argument as the line above, and it was missed: a tablet with no printer
    // inherited "always print" from the till and threw a dialog at the end of
    // every sale.
    'Print.AutoPrint',

    // ── The operator in front of THIS screen ──────────────────────────────
    // Language, text direction and the on-screen keyboard describe the person
    // and the hardware at one terminal, not the company. A French-speaking
    // waiter's tablet and an Arabic front till are both correct at once, and a
    // touch-only tablet needs the virtual keyboard that a Windows till with a
    // real keyboard must never get. Cloud-synced, they fought: setting the
    // language on the tablet re-languaged the till. Reported 2026-08-29.
    //
    // The cloud value still seeds a device that has never chosen — so a new
    // terminal opens in the venue's language and only diverges once someone
    // sets it here.
    'Application.Language',
    'App.WritingDirection',
    'App.EnableVirtualKeyboard',


    // The rest of the customer display was already per-terminal (`Enabled`,
    // `Port`, the serial parameters). These two describe the SAME physical
    // second screen — whether it is driven over the browser bridge, and how
    // many characters its panel fits — so they belong with them.
    'CustomerDisplay.WebEnabled',
    'CustomerDisplay.NumChars',
    'CustomerDisplay.Charset',

    // WHICH REGISTER this terminal is working. The one setting that must
    // differ between two terminals on the same account — that is the entire
    // point of having more than one — so cloud-syncing it would drag every
    // device onto whichever till was configured last, which is the opposite of
    // the feature. See `session/register_identity.dart`.
    'PosSession.RegisterUid',
    'PosSession.RegisterName',

    // Keyed BY `Kitchen.DisplayIps`, which is already per-terminal. Cloud-
    // syncing the mapping while the IPs it refers to are local means a device
    // holds group assignments for displays it cannot reach — and loses its own
    // the moment another terminal saves.
    'Kitchen.DisplayGroups',
  };

  /// Suffixes that make a key per-terminal whatever its role prefix.
  ///
  /// Printer roles are user-defined (`Printers.List`), so the set is open —
  /// `Receipt.PrinterName`, `Kitchen.PrinterName`, `Bar.PrinterName`… all name
  /// an OS-level print queue that only exists on the machine it was chosen on.
  /// Deliberately NOT included: paper size, margins, fonts, header/footer, RTL —
  /// those describe the *ticket*, which the venue does want identical everywhere.
  /// The cash-drawer wiring joins them for the same reason: the drawer is
  /// physically attached to ONE terminal. A Windows till with the drawer in its
  /// receipt printer's RJ11 port and a tablet reaching a LAN printer over TCP
  /// are both correct at the same time, and a cloud-synced transport would have
  /// each overwrite the other's. The *command bytes* are deliberately NOT here —
  /// those describe the printer model, which the venue does share.
  static const List<String> _suffixes = [
    '.PrinterName',
    // How the JOB reaches the printer, and where. Same argument as the drawer
    // below: the Windows till prints to a USB queue and the tablet prints to
    // the very same printer over the LAN, and each answer is wrong on the
    // other device.
    '.Connection',
    '.Host',
    '.TcpPort',
    '.CashDrawer.Transport',
    '.CashDrawer.Host',
    '.CashDrawer.TcpPort',
    '.CashDrawer.SerialPort',
    '.CashDrawer.BaudRate',
  ];

  static bool isDeviceScoped(String key) =>
      _exactKeys.contains(key) ||
      _suffixes.any((s) => key.endsWith(s));

  /// In-memory mirror so reads stay synchronous — `appSettingsProvider.build()`
  /// cannot await, exactly like the API base URL's `initApiBaseUrl`.
  static final Map<String, String> _cache = {};

  /// Snapshot of this device's overrides. Applied *last* in the settings merge,
  /// so it wins over both the cloud value and `kSettingDefaults`.
  static Map<String, String> get overrides => Map.unmodifiable(_cache);

  /// Loads the overrides into [_cache]. Call once at boot, BEFORE the first
  /// read of `appSettingsProvider`.
  static Future<void> init(SharedPreferences prefs) async {
    _cache.clear();
    for (final k in prefs.getKeys()) {
      if (!k.startsWith(_prefix)) continue;
      final v = prefs.getString(k);
      if (v != null) _cache[k.substring(_prefix.length)] = v;
    }
  }

  /// Persists a per-device value. Returns once it is on disk and in [_cache].
  static Future<void> set(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    _cache[key] = value;
    await prefs.setString('$_prefix$key', value);
  }

  /// Filters a value INHERITED from the cloud (i.e. this device has no override
  /// of its own) down to something this platform can actually act on.
  ///
  /// Returning null means "pretend it is unset" — the caller then falls back to
  /// `kSettingDefaults`, which is always platform-neutral. This is the guard
  /// that stops a Windows terminal's settings breaking a tablet before the
  /// operator has visited Settings even once:
  ///
  ///  * a drive-letter or UNC path is unreachable on Android/iOS, and
  ///    `BackupService.resolveBackupDir` would otherwise hand it straight to
  ///    `Directory(...).createSync()`;
  ///  * a Windows print-queue name can never resolve through
  ///    `Printing.listPrinters()` on Android (the plugin reports
  ///    `directPrint: false` there), so keeping it only makes the Printer
  ///    Settings screen claim a printer that is not there;
  ///  * a `COM*` port cannot exist on Android.
  static String? sanitizeInherited(String key, String value) {
    if (value.isEmpty) return value;

    final isMobile = Platform.isAndroid || Platform.isIOS;

    if (key == 'Database.BackupPath') {
      if (isMobile && _isDesktopPath(value)) return null;
      // 🚨 The mirror image, which was missing: a tablet's backup folder
      // inherited onto a fresh WINDOWS install. The operator opened Settings →
      // Database and found `/storage/emulated/0/Android/data/…` sitting in the
      // box on a machine that had never seen an Android device — and Windows
      // cannot write there. Reported 2026-08-16.
      //
      // Split by shape, not by "not mobile": a SAF `content://` URI is useless
      // on ANY desktop, while a POSIX-absolute path is only wrong on Windows —
      // macOS and Linux write `/Users/…` and `/home/…` and must be left alone.
      //
      // Dropping it falls through to `kSettingDefaults`, which is `''` — the
      // empty box the operator expected on a new install.
      if (!isMobile && value.contains('://')) return null;
      if (Platform.isWindows && value.startsWith('/')) return null;
    }
    if (key.endsWith('.PrinterName') && isMobile) return null;
    if ((key == 'Scale.Port' ||
            key == 'CustomerDisplay.Port' ||
            key.endsWith('.CashDrawer.SerialPort')) &&
        !Platform.isWindows &&
        value.toUpperCase().startsWith('COM')) {
      return null;
    }
    // A drawer transport inherited from a Windows till is unreachable on a
    // tablet — `printer` addresses a Windows print queue and `serial` a COM
    // port. Coerce rather than drop: the shipped default is `printer` too, so
    // returning null would land on the same dead end. Pointing at the one
    // transport Android has turns the failure into the useful "enter the
    // printer IP address" instead of "this needs Windows".
    if (key.endsWith('.CashDrawer.Transport') && isMobile) return 'network';
    // The same coercion for the printer itself, and for the same reason: a
    // 'system' connection inherited from a Windows till can only ever open the
    // Android print dialog. Pointing at 'network' turns a dead end into the
    // actionable "enter the printer IP address".
    if (key.endsWith('.Connection') &&
        !key.contains('CashDrawer') &&
        isMobile) {
      return 'network';
    }
    return value;
  }

  /// `D:\x`, `\\server\share` or `C:/x` — a Windows-shaped location.
  static bool _isDesktopPath(String value) {
    if (value.startsWith(r'\\')) return true;
    return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value);
  }
}
