/// Export of the product catalogue or its groups: the format choice, the fetch
/// and the save, shared by the Products and Product Groups screens.
///
/// The file formats themselves live in `catalog_transfer.dart`, where the round
/// trip is tested; this is only the plumbing around them.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_app/api/api_client.dart';
import 'package:pos_app/company/company_provider.dart';
import 'package:pos_app/core/status_colors.dart';
import 'package:pos_app/l10n/app_localizations.dart';
import 'package:pos_app/product/catalog_transfer.dart';
import 'package:pos_app/product/product_export_model.dart';
import 'package:pos_app/utils/api_error_parser.dart';
import 'package:pos_app/utils/snackbar_helper.dart';

enum CatalogExportKind { products, groups }

/// Asks CSV or XML, then exports. One tap per format — there is nothing else to
/// decide, so there is no Continue button to press after choosing.
Future<void> showCatalogExportDialog(
  BuildContext context,
  WidgetRef ref,
  CatalogExportKind kind,
) async {
  final l = AppLocalizations.of(context);
  final format = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l.selectExportType),
      children: [
        _FormatOption(
          icon: Icons.table_chart_rounded,
          color: ctx.successColor,
          title: l.exportCsv,
          subtitle: l.exportCsvHint,
          onTap: () => Navigator.pop(ctx, 'csv'),
        ),
        _FormatOption(
          icon: Icons.code_rounded,
          color: ctx.infoColor,
          title: l.exportXml,
          subtitle: l.exportXmlHint,
          onTap: () => Navigator.pop(ctx, 'xml'),
        ),
      ],
    ),
  );
  if (format == null || !context.mounted) return;
  await _export(context, ref, kind, format);
}

Future<void> _export(
  BuildContext context,
  WidgetRef ref,
  CatalogExportKind kind,
  String format,
) async {
  final company = ref.read(selectedCompanyProvider);
  if (company == null) return;
  final l = AppLocalizations.of(context);
  final groups = kind == CatalogExportKind.groups;

  try {
    final dio = createDio();
    final query = {'companyId': company.id};

    Future<List<GroupNode>> fetchGroups() async {
      final r = await dio.get('/ProductGroups/GetForExport', queryParameters: query);
      return [
        for (final e in r.data as List)
          GroupNode.fromExportJson(Map<String, dynamic>.from(e as Map)),
      ];
    }

    final String content;
    final int count;
    if (groups) {
      final nodes = await fetchGroups();
      content = format == 'csv' ? buildGroupsCsv(nodes) : buildGroupsXml(nodes);
      count = nodes.length;
    } else {
      final r = await dio.get('/Products/GetForExport', queryParameters: query);
      final rows = [
        for (final e in r.data as List)
          ProductExportRow.fromJson(Map<String, dynamic>.from(e as Map)),
      ];
      // The CSV names each product's own group; only the XML carries the tree,
      // so only the XML needs it.
      content = format == 'csv'
          ? buildProductsCsv(rows)
          : buildProductsXml(rows, await fetchGroups());
      count = rows.length;
    }

    final bytes = Uint8List.fromList(utf8.encode(content));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l.saveExportFileTitle,
      fileName: '${groups ? 'product_groups' : 'products'}_export.$format',
      type: FileType.custom,
      allowedExtensions: [format],
      // Android and iOS write the file from these bytes and only report where
      // it went. The desktop pickers just choose a path — written below.
      bytes: bytes,
    );
    if (path == null) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await File(path).writeAsBytes(bytes, flush: true);
    }

    if (context.mounted) {
      showAppSnackbar(
        context,
        ref,
        groups ? l.exportedGroupsTo(count, path) : l.exportedProductsTo(count, path),
      );
    }
  } catch (e) {
    if (context.mounted) {
      showAppSnackbar(context, ref, l.exportFailed(parseApiError(e)), isError: true);
    }
  }
}

class _FormatOption extends StatelessWidget {
  const _FormatOption({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: Text(subtitle),
      minVerticalPadding: 12,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      onTap: onTap,
    );
  }
}
