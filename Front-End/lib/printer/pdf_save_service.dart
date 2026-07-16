import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pos_app/printer/pdf_file_name.dart';

/// "Save as PDF" — opens the system file-save dialog with the file name already
/// filled in, then writes the bytes.
///
/// This is the one flow whose default name the app fully controls. Printing to
/// a PDF *printer* only gets to suggest a name (via the print job), and whether
/// the box is pre-filled is then up to the printer driver; here it always is.
///
/// [suggestedName] must NOT carry the `.pdf` extension — use the builders in
/// `pdf_file_name.dart` and let this add it.
///
/// Returns the written path, or null if the operator cancelled.
Future<String?> savePdfAs({
  required Uint8List bytes,
  required String suggestedName,
  String dialogTitle = 'Save as PDF',
}) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: dialogTitle,
    // Non-negotiable: file_picker throws IllegalCharacterInFileNameException on
    // Windows if the name holds a forbidden character, and order names are
    // operator-typed. `pdfSafeName` is what stops a bad name from becoming a
    // crash rather than just an ugly file.
    fileName: '${pdfSafeName(suggestedName)}.pdf',
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    // Required on Android/iOS — file_picker throws ArgumentError without it and
    // writes the file itself there. Desktop ignores this and only returns a
    // path, so the write below is still needed. Passing it always is what makes
    // this work on both the Windows POS and the Android tablets.
    bytes: bytes,
  );
  if (path == null) return null;

  // On desktop the dialog only picked a location — the file does not exist yet.
  // On Android/iOS the plugin already wrote it from `bytes`.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(path).writeAsBytes(bytes);
  }
  return path;
}
