import 'dart:io' as io;

import 'package:book/book.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() => group('EPUB', () {
      test(
        'schema',
        () async {
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
            final readingOrder = metadata.navigation.getReadingOrder();
            {
              if (readingOrder.length > 1) {
                for (var i = 1; i < readingOrder.length; i++) {
                  expect(
                    readingOrder[i].playorder,
                    greaterThan(
                      readingOrder[i - 1].playorder,
                    ),
                  );
                }
              }
            }

            expect(readingOrder, isA<List<BookNavigation$Point>>());
          }
        },
        skip: true,
      );

      test(
        'epub_v2',
        () {
          final book = Book.epub(
              io.File('temp/Mushoku Tensei - 1.epub').readAsBytesSync());
          final metadata = book.getMetadata();
          final image = book.getCoverImage(metadata);
          expect(metadata, isA<BookMetadata>());
        },
      );
    });
