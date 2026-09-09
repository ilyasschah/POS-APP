import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pos_app/auth/user_model.dart';
import 'package:pos_app/l10n/app_localizations.dart';

/// One place that decides what a ROLE looks like.
///
/// Access level 0 is the administrator; every other level is a cashier. That
/// test was copy-pasted into the login grid, the PIN pad, the profile header
/// and the user list, each with its own colours — so the two roles were only
/// ever told apart by a colour swatch, which is invisible to a cashier walking
/// up to a wall of identical person glyphs. The glyph itself now carries the
/// difference, and the colours come from the theme (never hardcoded, so dark
/// mode keeps working).
extension UserRole on User {
  bool get isAdmin => accessLevel == 0;
}

/// The glyph that separates the roles at a glance: the admin is a person with
/// a gear (the one who configures the terminal), the cashier is the till.
/// Silhouettes differ, so they stay distinguishable at avatar size and across
/// the accent colours a company may pick.
IconData roleIcon(
  bool isAdmin, {
  PhosphorIconsStyle style = PhosphorIconsStyle.fill,
}) =>
    isAdmin ? PhosphorIcons.userGear(style) : PhosphorIcons.cashRegister(style);

/// Avatar colours for a role, sourced from the Material 3 scheme so both
/// themes stay legible. Admin takes the primary container, cashier the
/// secondary one.
({Color background, Color foreground}) roleAvatarColors(
  ColorScheme cs,
  bool isAdmin,
) =>
    isAdmin
        ? (background: cs.primaryContainer, foreground: cs.onPrimaryContainer)
        : (
            background: cs.secondaryContainer,
            foreground: cs.onSecondaryContainer,
          );

/// Localised role name. Re-read per build — the locale is not stable at
/// sign-in (the company's language arrives with the post-sign-in sync).
String roleLabel(BuildContext context, bool isAdmin) => isAdmin
    ? AppLocalizations.of(context).roleAdmin
    : AppLocalizations.of(context).roleCashier;
