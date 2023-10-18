import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart' as zip;
import 'package:book/book.dart';
import 'package:book/src/epub/epub.dart';
import 'package:book/src/exception.dart';
import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart' as crypto show sha256;
import 'package:meta/meta.dart';
import 'package:xml/xml.dart' as xml;

/// {@nodoc}
@immutable
@internal
final class BookSnapshotExtractor extends Converter<Uint8List, Book> {
  /// {@nodoc}
  const BookSnapshotExtractor();

  @override
  Book convert(Uint8List input) {
    const kContainerFilePath = 'META-INF/container.xml';
    const kContainerNamespace =
        'urn:oasis:names:tc:opendocument:xmlns:container';

    final hash = crypto.sha256.convert(input).toString();
    final archive = zip.ZipDecoder().decodeBytes(input);
    final containerFileEntry = archive.files
        .firstWhereOrNull((file) => file.name == kContainerFilePath);
    if (containerFileEntry == null) {
      throw const BookException(
        'epub_missing_container_file',
        'Parsing error: $kContainerFilePath file not found in archive.',
      );
    }
    final content = containerFileEntry.content;
    if (content is! List<int>) {
      throw const BookException(
        'epub_invalid_container_file',
        'Parsing error: $kContainerFilePath file content is not a bytes.',
      );
    }
    final containerDocument = xml.XmlDocument.parse(utf8.decode(content));
    final packageElement = containerDocument
        .findAllElements(
          'container',
          namespace: kContainerNamespace,
        )
        .firstOrNull;
    if (packageElement == null) {
      throw const BookException(
        'epub_invalid_container_file',
        'Parsing error: $kContainerFilePath file content is not a valid XML.',
      );
    }
    final rootFileElement = packageElement.descendants
        .whereType<xml.XmlElement>()
        .firstWhereOrNull((elem) => 'rootfile' == elem.name.local);
    if (rootFileElement == null) {
      throw const BookException(
        'epub_invalid_container_file',
        'Parsing error: $kContainerFilePath file content is not a valid XML.',
      );
    }
    final rootFilePath = rootFileElement.getAttribute('full-path');
    if (rootFilePath == null) {
      throw const BookException(
        'epub_invalid_container_file',
        'Parsing error: $kContainerFilePath file content is not a valid XML.',
      );
    }

    return Epub(
      hash: hash,
      archive: archive,
      rootFile: rootFilePath,
    );
  }
}
