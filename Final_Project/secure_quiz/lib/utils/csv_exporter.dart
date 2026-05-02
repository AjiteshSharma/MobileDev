import 'csv_exporter_stub.dart'
    if (dart.library.html) 'csv_exporter_web.dart'
    as exporter;
import 'csv_export_models.dart';

Future<CsvExportResult> exportCsvFile({
  required String fileName,
  required String csvContent,
}) {
  return exporter.exportCsvFileImpl(fileName: fileName, csvContent: csvContent);
}
