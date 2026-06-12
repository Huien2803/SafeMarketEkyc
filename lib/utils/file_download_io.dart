import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import 'file_download_result.dart';

Future<FileDownloadResult> platformDownloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  await Clipboard.setData(ClipboardData(text: content));
  return const FileDownloadResult(
    method: FileDownloadMethod.copiedToClipboard,
    message: 'Đã sao chép báo cáo — dán vào Excel hoặc Google Sheets',
  );
}

Future<FileDownloadResult> platformDownloadBytes({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/pdf',
}) async {
  await Printing.sharePdf(bytes: bytes, filename: fileName);
  return FileDownloadResult(
    method: FileDownloadMethod.downloaded,
    message: 'Đã mở hộp thoại chia sẻ PDF',
  );
}
