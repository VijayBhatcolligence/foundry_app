// D8.7: Download and Checksum Tests

import 'package:flutter_test/flutter_test.dart';
import 'package:foundry_shell/modules/module_downloader.dart';

void main() {
  group('ModuleDownloader', () {
    late ModuleDownloader downloader;

    setUp(() {
      downloader = ModuleDownloader();
    });

    test('isDownloading returns false for new URL', () {
      expect(downloader.isDownloading('https://example.com/test.js'), false);
    });

    test('getProgress returns null for non-downloading URL', () {
      expect(downloader.getProgress('https://example.com/test.js'), null);
    });

    test('Download with invalid URL fails', () async {
      final result = await downloader.downloadModule(
        downloadUrl: 'invalid-url',
        expectedChecksum: 'a' * 64,
        expectedSizeBytes: 1024,
      );

      expect(result.success, false);
      expect(result.error, isNotNull);
    });

    test('Download with unreachable URL fails with retry', () async {
      final result = await downloader.downloadModule(
        downloadUrl: 'https://nonexistent.example.invalid/module.js',
        expectedChecksum: 'a' * 64,
        expectedSizeBytes: 1024,
      );

      expect(result.success, false);
      expect(result.error, isNotNull);
      expect(result.checksumValid, false);
    });
  });
}
