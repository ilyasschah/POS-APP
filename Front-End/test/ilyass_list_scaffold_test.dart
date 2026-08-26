// The shared chrome for a management list screen.
//
// The bug that earned the hero-tag test: ManagementLayout keeps every visited
// screen alive in a LazyIndexedStack, so two screens with a FAB are mounted in
// ONE Navigator subtree at the same time. Flutter's default FAB hero tag is a
// shared constant, so the second one to mount collided with the first and every
// route animation afterwards threw "multiple heroes share the same tag".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/ilyass_list_scaffold.dart';
import 'package:pos_app/l10n/app_localizations.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      );

  group('the FAB', () {
    testWidgets('carries a tag of its own screen, not the shared default',
        (tester) async {
      await tester.pumpWidget(host(const IlyassListScaffold(
        title: 'Products',
        fabLabel: 'Add Product',
        body: SizedBox(),
      )));

      final hero = tester.widget<Hero>(find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byType(Hero),
      ).first);

      expect(hero.tag, 'ilyass-fab-Products');
    });

    testWidgets('two screens alive at once do not collide', (tester) async {
      // Exactly the LazyIndexedStack shape: both screens built, one visible.
      await tester.pumpWidget(host(const IndexedStack(
        index: 0,
        children: [
          IlyassListScaffold(
            title: 'Products',
            fabLabel: 'Add Product',
            body: SizedBox(),
          ),
          IlyassListScaffold(
            title: 'Documents',
            fabLabel: 'New',
            body: SizedBox(),
          ),
        ],
      )));

      // skipOffstage: false — IndexedStack keeps the hidden child in the tree
      // but off it, and the hidden child's FAB is exactly the one that used to
      // collide with the visible one.
      final tags = tester
          .widgetList<Hero>(find.descendant(
            of: find.byType(FloatingActionButton, skipOffstage: false),
            matching: find.byType(Hero, skipOffstage: false),
            skipOffstage: false,
          ))
          .map((h) => h.tag)
          .toList();

      expect(tags.length, 2);
      expect(tags.toSet().length, 2,
          reason: 'two mounted FABs must not share a hero tag');
      expect(tester.takeException(), isNull);
    });

    testWidgets('no fabLabel means no FAB at all', (tester) async {
      // Stock creates nothing, so it has none.
      await tester.pumpWidget(host(const IlyassListScaffold(
        title: 'Stock',
        body: SizedBox(),
      )));

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('the ⋮ menu', () {
    testWidgets('a disabled action is still listed, greyed', (tester) async {
      // An operator has to see that Delete exists before they understand they
      // must tick something first.
      await tester.pumpWidget(host(IlyassListScaffold(
        title: 'Products',
        body: const SizedBox(),
        actions: [
          IlyassMenuAction(
            icon: Icons.delete,
            label: 'Delete',
            enabled: false,
            onSelected: () {},
          ),
          IlyassMenuAction(
            icon: Icons.view_column,
            label: 'Columns',
            onSelected: () {},
          ),
        ],
      )));

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
      expect(find.text('Columns'), findsOneWidget);
    });

    testWidgets('picking an entry runs that entry', (tester) async {
      final fired = <String>[];
      await tester.pumpWidget(host(IlyassListScaffold(
        title: 'Products',
        body: const SizedBox(),
        actions: [
          IlyassMenuAction(
            icon: Icons.delete,
            label: 'Delete',
            onSelected: () => fired.add('delete'),
          ),
          IlyassMenuAction(
            icon: Icons.view_column,
            label: 'Columns',
            onSelected: () => fired.add('columns'),
          ),
        ],
      )));

      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Columns'));
      await tester.pumpAndSettle();

      expect(fired, ['columns'],
          reason: 'the index must map to the action it was built from');
    });

    testWidgets('no actions means no menu button', (tester) async {
      await tester.pumpWidget(host(const IlyassListScaffold(
        title: 'Products',
        body: SizedBox(),
      )));

      expect(find.byType(PopupMenuButton<int>), findsNothing);
    });
  });
}
