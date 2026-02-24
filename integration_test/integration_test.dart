import 'package:integration_test/integration_test.dart';

import 'tests/import_pipeline_tests.dart' as import_pipeline;
import 'tests/ocr_pipeline_tests.dart' as ocr_pipeline;
import 'tests/pdf_metadata_reader_tests.dart' as pdf_metadata_reader;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  import_pipeline.main();
  ocr_pipeline.main();
  pdf_metadata_reader.main();
}
