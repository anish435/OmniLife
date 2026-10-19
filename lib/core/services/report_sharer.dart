import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Hands a finished report to the person: a download in the browser, the
/// system share sheet on Android. Behind an interface so tests never touch
/// a platform plugin.
abstract class ReportSharer {
  Future<void> sharePdf(Uint8List bytes, String filename);
}

class PrintingReportSharer implements ReportSharer {
  const PrintingReportSharer();

  @override
  Future<void> sharePdf(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);
}
