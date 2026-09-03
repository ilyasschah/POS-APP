// The one guarantee `SecureStore` exists to make: no two secure-storage
// operations are ever in flight at once.
//
// It matters because `flutter_secure_storage_windows` keeps ONE DPAPI file and
// takes no lock over it. `save()` truncates and rewrites the whole file, so two
// overlapping writes interleave into a blob DPAPI cannot decrypt — and the
// `load()` that then tries to bin that blob races the other operation's handle
// and dies with errno 32, leaving the bad file in place to fail again for ever.
//
// So this asserts the property, not the plumbing: whatever the callers do, the
// operations run one at a time and in the order they were asked for.
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/secure_storage.dart';

void main() {
  group('SecureStore serialisation', () {
    test('operations never overlap, however they are fired', () async {
      var inFlight = 0;
      var maxInFlight = 0;

      Future<void> op(int ms) => SecureStore.runSerially(() async {
            inFlight++;
            maxInFlight = maxInFlight > inFlight ? maxInFlight : inFlight;
            await Future<void>.delayed(Duration(milliseconds: ms));
            inFlight--;
          });

      // Fired together and deliberately out of duration order — the way a sync
      // tick fires a token refresh and a lease read at the same moment.
      await Future.wait([op(30), op(1), op(20), op(1), op(10)]);

      expect(maxInFlight, 1, reason: 'two storage operations overlapped');
      expect(inFlight, 0);
    });

    test('order is preserved', () async {
      final order = <int>[];
      await Future.wait([
        for (var i = 0; i < 5; i++)
          SecureStore.runSerially(() async {
            await Future<void>.delayed(Duration(milliseconds: 5 - i));
            order.add(i);
          }),
      ]);
      expect(order, [0, 1, 2, 3, 4]);
    });

    test('a failed operation does not poison the ones behind it', () async {
      // The lane is a single chained future. If a throw were allowed to
      // complete that chain with an error, every later call would inherit the
      // failure — a corrupt read would take the whole session down with it.
      final boom = SecureStore.runSerially<void>(() async {
        throw StateError('storage is unreadable');
      });
      await expectLater(boom, throwsStateError);

      final after = await SecureStore.runSerially<String>(() async => 'ok');
      expect(after, 'ok');
    });
  });
}
