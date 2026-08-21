// The final gate: "no sale without an open session".
//
// 🚨 The property that matters most here is NOT that it blocks — it is that it
// blocks only when it is SURE. This gate sits on the money path and on the
// first action of every trading day, so a gate that said "no" whenever it was
// unsure would let a transient fault (device id still resolving, a Drift
// hiccup) close a shop. Every "unknown" case below must allow.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/session/pos_session_status.dart';
import 'package:pos_app/session/session_gate.dart';

void main() {
  /// Mirrors `sessionGateProvider`'s decision table, without a container.
  SessionGate decide({
    required bool enforced,
    required bool contextReady,
    required bool sessionKnown,
    int? status,
  }) {
    if (!enforced) return SessionGate.allowed;
    if (!contextReady) return SessionGate.unknown;
    if (!sessionKnown) return SessionGate.unknown;
    if (status == null) return SessionGate.blockedNoSession;
    return PosSessionStatus.canSell(status)
        ? SessionGate.allowed
        : SessionGate.blockedNotTrading;
  }

  bool allows(SessionGate g) =>
      g == SessionGate.allowed || g == SessionGate.unknown;

  group('it blocks only when it is sure', () {
    test('an OPENED session sells', () {
      expect(
        decide(
            enforced: true,
            contextReady: true,
            sessionKnown: true,
            status: PosSessionStatus.opened),
        SessionGate.allowed,
      );
    });

    test('no session at all is the ONE positive block', () {
      final g = decide(
          enforced: true, contextReady: true, sessionKnown: true, status: null);
      expect(g, SessionGate.blockedNoSession);
      expect(allows(g), isFalse);
    });

    test('a live-but-not-trading session blocks, with a different reason', () {
      // OPENING_CONTROL: the float is not confirmed, so no expected-cash figure
      // is meaningful yet. CLOSING_CONTROL: the drawer is being counted and a
      // sale would invalidate the number being signed.
      for (final s in [
        PosSessionStatus.openingControl,
        PosSessionStatus.closingControl,
      ]) {
        expect(
          decide(
              enforced: true,
              contextReady: true,
              sessionKnown: true,
              status: s),
          SessionGate.blockedNotTrading,
          reason: PosSessionStatus.name(s),
        );
      }
    });

    test('a CLOSED session blocks', () {
      expect(
        decide(
            enforced: true,
            contextReady: true,
            sessionKnown: true,
            status: PosSessionStatus.closed),
        SessionGate.blockedNotTrading,
      );
    });
  });

  group('it FAILS OPEN — the safety property', () {
    test('company or device id not resolved yet still sells', () {
      final g = decide(
          enforced: true, contextReady: false, sessionKnown: true, status: null);
      expect(g, SessionGate.unknown);
      expect(allows(g), isTrue,
          reason: 'a loading device id must never stop a shop trading');
    });

    test('a session query that is loading or errored still sells', () {
      final g = decide(
          enforced: true, contextReady: true, sessionKnown: false, status: null);
      expect(allows(g), isTrue);
    });

    test('the master switch off sells regardless of session state', () {
      // The recovery path: a wrong session row on a real till must be
      // fixable from Settings, not only by a developer.
      for (final s in [null, PosSessionStatus.closed, PosSessionStatus.opened]) {
        expect(
          decide(
              enforced: false,
              contextReady: true,
              sessionKnown: true,
              status: s),
          SessionGate.allowed,
        );
      }
    });

    test('every unknown path allows, exhaustively', () {
      for (final ready in [true, false]) {
        for (final known in [true, false]) {
          final g = decide(
              enforced: true,
              contextReady: ready,
              sessionKnown: known,
              status: PosSessionStatus.opened);
          expect(allows(g), isTrue,
              reason: 'ready=$ready known=$known with an OPENED session');
        }
      }
    });
  });

  test('only OPENED is a selling state', () {
    expect(PosSessionStatus.canSell(PosSessionStatus.opened), isTrue);
    for (final s in [
      PosSessionStatus.openingControl,
      PosSessionStatus.closingControl,
      PosSessionStatus.closed,
    ]) {
      expect(PosSessionStatus.canSell(s), isFalse, reason: '$s');
    }
  });
}
