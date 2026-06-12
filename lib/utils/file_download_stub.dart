import 'dart:typed_data';

import 'file_download_result.dart';

Future<FileDownloadResult> platformDownloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) {
  throw UnsupportedError('Tải file không hỗ trợ trên nền tảng này');
}

Future<FileDownloadResult> platformDownloadBytes({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/pdf',
}) {
  throw UnsupportedError('Tải file không hỗ trợ trên nền tảng này');
}
