import 'dart:io' as io;

import 'package:book/book.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() => group('EPUB', () {
      test('schema', () async {
        final books = io.Directory('temp')
            .listSync(recursive: true)
            .whereType<io.File>()
            .where((file) => p.extension(file.path).toLowerCase() == '.epub')
            .toList(growable: false);
        for (final samplebook in books) {
          final bytes = samplebook.readAsBytesSync();
          final book = Book.epub(bytes);
          expect(book, isA<Book>());
          final metadata = book.getMetadata();
          expect(metadata, isA<BookMetadata>());
        }
      });
    });
