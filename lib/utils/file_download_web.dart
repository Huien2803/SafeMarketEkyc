import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'file_download_result.dart';

Future<FileDownloadResult> platformDownloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  final bytes = utf8.encode(content);
  return platformDownloadBytes(
    fileName: fileName,
    bytes: Uint8List.fromList(bytes),
    mimeType: mimeType,
  );
}

Future<FileDownloadResult> platformDownloadBytes({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/pdf',
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  await Future<void>.delayed(const Duration(milliseconds: 200));
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return FileDownloadResult(
    method: FileDownloadMethod.downloaded,
    message: 'Đã tải file $fileName',
  );
}
