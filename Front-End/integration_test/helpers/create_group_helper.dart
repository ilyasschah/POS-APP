/// `createProductGroup` — one product group, through Management → Product Groups.
///
/// ```dart
/// await createProductGroup(tester, ctx);                        // a root folder
/// await createProductGroup(tester, ctx, name: 'Hot Drinks',
///                          parent: ctx.groupName);              // a child of it
/// await createProductGroup(tester, ctx, underFirstAvailable: true);
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../config/test_config.dart';
import '../support/e2e_support.dart';
import 'e2e_context.dart';

/// Creates a product group and records it on [ctx] as `groupName`.
///
/// Assumes `loginToCompany` has already run; navigates to the section itself.
///
/// ## Where it gets put
///
/// * [parent] named            → under that folder.
/// * [underFirstAvailable]     → under the first REAL folder the dropdown
///                               offers (the Index 0 rule).
/// * neither                   → at the root, `None (Root)`.
///
/// 🚨 Root is the default rather than index 0, and the distinction matters. The
/// Parent Folder dropdown is built as a null-valued placeholder followed by the
/// folders, so its literal index 0 IS `None (Root)`. Defaulting to "first
/// available" would therefore bury every generated folder inside whatever
/// happens to sort first on that company — reproducible only by accident.
/// A caller who genuinely wants nesting says so.
Future<String> createProductGroup(
  WidgetTester tester,
  E2EContext ctx, {
  String? name,
  String? parent,
  bool underFirstAvailable = false,
  int swatch = 1,
  String? rank,
}) async {
  final groupName = name ?? tagged(kParentGroupName);

  await ensureManagementSection(tester, ctx.l, ctx.l.productGroups);
  step('Product Groups opened');

  // A stale filter would hide the parent from the list AND leave the editor's
  // dropdown looking at a shorter list than the company really has.
  await clearSearch(tester);

  await tapVisible(tester, find.text(ctx.l.newGroup));
  await waitFor(
    tester,
    find.widgetWithText(TextFormField, ctx.l.groupNameHint),
  );

  // 🚨 Everything below is scoped to the dialog, and that is not tidiness.
  // While the list is empty the screen behind carries its own "Create Group"
  // button, so an unscoped finder matches TWO — and the first in tree order is
  // the one UNDERNEATH, sitting behind the modal barrier where the tap lands on
  // nothing at all. The dialog then just sits there until the test times out.
  final dialog = find.byType(Dialog);

  await fillField(tester, ctx.l.groupNameHint, groupName, within: dialog);

  // 🚨 Wait for the Parent Folder dropdown to EXIST before reaching for it. It
  // is built from `allProductGroupsProvider`, an autoDispose stream that
  // re-subscribes each time this dialog opens — and while it loads the editor
  // renders a LinearProgressIndicator in the dropdown's place. So the field is
  // genuinely absent for the first moment of every open, and a finder that runs
  // then reports "no dropdown" about one that is merely late.
  await waitFor(
    tester,
    find.descendant(of: dialog, matching: anyDropdownField),
    timeout: const Duration(seconds: 30),
    because: 'The Parent Folder dropdown never finished loading.',
  );

  String? resolvedParent;
  if (parent != null) {
    await pickDropdown(tester, ctx.l.parentFolder, parent, within: dialog);
    resolvedParent = parent;
    step('Parent folder: "$parent" (named by the caller)');
  } else if (underFirstAvailable) {
    resolvedParent = await pickDropdownAt(
      tester,
      ctx.l.parentFolder,
      within: dialog,
    );
    step('Parent folder: "$resolvedParent" (first available)');
  } else {
    await pickDropdown(tester, ctx.l.parentFolder, ctx.l.noneRoot,
        within: dialog);
    step('Parent folder: root');
  }

  // The rank field has no label of its own — it is identified by its "0" hint.
  await fillField(tester, '0', rank ?? kDisplayRank, within: dialog);

  // The folder IMAGE is deliberately not set. `_pickImage` calls
  // `ImagePicker().pickImage`, which opens the OPERATING SYSTEM's file dialog —
  // a window outside the Flutter tree that a widget test cannot see or click.
  // A colour is the same field's alternative in the UI.
  await pickSwatch(tester, swatch);

  final saveButton = find.descendant(
    of: dialog,
    matching: find.widgetWithText(FilledButton, ctx.l.createGroup),
  );
  await tapVisible(tester, saveButton);
  await waitForGone(tester, saveButton, timeout: const Duration(seconds: 60));
  await pumpFor(tester, const Duration(seconds: 2));

  // 🚨 Wait for the group to appear in the LIST, not just for the dialog to
  // close. The Parent Folder dropdown is fed by the same provider as the table,
  // and that provider refreshes asynchronously after a save — so a caller that
  // immediately creates a CHILD gets a dropdown that does not yet contain the
  // folder the child is supposed to go in.
  await searchList(tester, groupName);
  await waitFor(
    tester,
    find.textContaining(groupName),
    timeout: const Duration(seconds: 60),
    because: 'The new group never reached the list.',
  );
  await clearSearch(tester);

  ctx.groupName = groupName;
  if (resolvedParent != null) ctx.parentGroupName = resolvedParent;
  ctx.record(E2EArtifact(
    table: 'ProductGroup',
    name: groupName,
    extra: {'Parent': resolvedParent},
  ));

  step('Group created: $groupName${resolvedParent == null ? ' (root)' : ' '
      '(child of $resolvedParent)'}');
  return groupName;
}
