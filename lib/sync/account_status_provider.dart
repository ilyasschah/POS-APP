import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Set to `true` when a sync detects — via a definitive server response — that
/// this terminal's company/tenant no longer exists (deleted in the admin
/// portal). The app shell ([MainLayout]) watches this and routes back to the
/// master login, unlinking the device. NEVER set on an offline/transient error,
/// so a network blip can't kick a legitimate offline terminal out.
class AccountRevokedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markRevoked() => state = true;
  void reset() => state = false;
}

final accountRevokedProvider =
    NotifierProvider<AccountRevokedNotifier, bool>(AccountRevokedNotifier.new);
