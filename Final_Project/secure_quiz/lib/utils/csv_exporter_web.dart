// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'csv_export_models.dart';

Future<CsvExportResult> exportCsvFileImpl({
  required String fileName,
  required String csvContent,
}) async {
  final bytes = utf8.encode(csvContent);
  final blob = html.Blob(<Object>[bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);

  return const CsvExportResult(downloaded: true, message: 'CSV downloaded.');
}
