import 'package:flutter/services.dart';

import 'csv_export_models.dart';

Future<CsvExportResult> exportCsvFileImpl({
  required String fileName,
  required String csvContent,
}) async {
  await Clipboard.setData(ClipboardData(text: csvContent));
  return const CsvExportResult(
    downloaded: false,
    message:
        'CSV copied to clipboard. Direct file download is available in web builds.',
  );
}
