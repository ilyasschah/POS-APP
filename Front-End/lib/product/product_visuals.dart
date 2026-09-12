import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// One place that decides what a product looks like when it has no image.
///
/// It was a fork and knife everywhere, which reads as "food" — but this POS
/// also sells services (a repair, a haircut, a delivery fee), and a service
/// drawn as a meal is simply wrong on a salon's or a workshop's till. The
/// product's own `isService` flag picks the glyph, so every placeholder in the
/// app — the POS grid, the Products table, the editor — agrees.
IconData productPlaceholderIcon({required bool isService}) => isService
    ? PhosphorIconsRegular.handshake
    : PhosphorIconsRegular.forkKnife;
