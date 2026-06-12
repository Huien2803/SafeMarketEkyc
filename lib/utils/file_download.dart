import 'dart:typed_data';

import 'file_download_result.dart';
import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    if (dart.library.io) 'file_download_io.dart';

export 'file_download_result.dart';

/// Tải file CSV (web) hoặc sao chép nội dung (mobile/desktop).
Future<FileDownloadResult> downloadTextFile({
  required String fileName,
  required String content,
  String mimeType = 'text/csv;charset=utf-8',
}) =>
    platformDownloadTextFile(
      fileName: fileName,
      content: content,
      mimeType: mimeType,
    );

/// Tải file nhị phân — PDF (web: download, mobile: share).
Future<FileDownloadResult> downloadBytes({
  required String fileName,
  required Uint8List bytes,
  String mimeType = 'application/pdf',
}) =>
    platformDownloadBytes(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
