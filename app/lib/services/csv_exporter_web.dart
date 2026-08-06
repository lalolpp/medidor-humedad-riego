// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveCsv(String data, String fileName) async {
  final blob = html.Blob([Uint8List.fromList(data.codeUnits)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)..download = fileName;
  anchor.click();
  html.Url.revokeObjectUrl(url);
}
