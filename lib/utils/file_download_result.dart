enum FileDownloadMethod { downloaded, copiedToClipboard }

class FileDownloadResult {
  const FileDownloadResult({required this.method, this.message});

  final FileDownloadMethod method;
  final String? message;
}
