import 'dart:convert';

import 'package:book/src/book.dart';
import 'package:book/src/epub/epub.dart';

/// {@nodoc}
final class EpubMetadataJsonConverter
    extends Converter<Map<String, Object?>, EpubMetadata> {
  /// {@nodoc}
  const EpubMetadataJsonConverter();

  @override
  EpubMetadata convert(Map<String, Object?> input) {
    final metadata = EpubMetadata();
    void extractStrings(
        String key, void Function(Iterable<BookMetadataValue> v) fn) {
      final values = input[key];
      if (values is String) {
        fn(<BookMetadataValue>[BookMetadataValue(values)]);
      } else if (values is Iterable<Object?>) {
        fn(values
            .map<BookMetadataValue?>((v) => switch (v) {
                  String v => BookMetadataValue(v),
                  Map<String, Object?> v => BookMetadataValue.fromJson(v),
                  _ => null,
                })
            .whereType<BookMetadataValue>());
      }
    }

    extractStrings('title', metadata.title.addAll);
    extractStrings('creator', metadata.creator.addAll);
    extractStrings('contributor', metadata.contributor.addAll);
    extractStrings('publisher', metadata.publisher.addAll);
    extractStrings('relation', metadata.relation.addAll);
    extractStrings('subject', metadata.subject.addAll);
    extractStrings('language', metadata.language.addAll);
    extractStrings('identifier', metadata.identifier.addAll);
    extractStrings('description', metadata.description.addAll);
    extractStrings('date', metadata.date.addAll);
    extractStrings('type', metadata.type.addAll);
    extractStrings('format', metadata.format.addAll);
    extractStrings('source', metadata.source.addAll);
    extractStrings('coverage', metadata.coverage.addAll);
    extractStrings('rights', metadata.rights.addAll);
    extractStrings('meta', metadata.meta.addAll);
    metadata
      ..epubVersion = input['@version']?.toString() ?? ''
      ..epubManifest = switch (input['@manifest']) {
        Map<String, Object?> json => EpubManifest.fromJson(json),
        _ => EpubManifest(),
      }
      ..epubSpine = switch (input['@spine']) {
        Map<String, Object?> json => EpubSpine.fromJson(json),
        _ => EpubSpine(),
      }
      ..epubNavigation = switch (input['@navigation']) {
        Map<String, Object?> json => EpubNavigation.fromJson(json),
        _ => EpubNavigation(),
      };
    return metadata;
  }
}
