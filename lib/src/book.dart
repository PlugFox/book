import 'dart:convert';
import 'dart:typed_data';

import 'package:book/src/epub/epub_metadata_json_decoder.dart';
import 'package:book/src/epub/epub_snapshot_extractor.dart';
import 'package:meta/meta.dart';

/// A book snapshot.
@immutable
abstract base class Book {
  /// A book snapshot.
  const Book();

  /// Creates a epub book snapshot from the given [bytes].
  factory Book.epub(Uint8List bytes) =>
      const BookSnapshotExtractor().convert(bytes);

  /// Book SHA-256 hash (hexadecimal string)
  abstract final String hash;

  /// Book metadata (title, author, etc.).
  /// Used to display book information and get other book data.
  BookMetadata getMetadata();

  /// Get book cover image.
  BookResource? getCoverImage(BookMetadata metadata);

  /// Get book page by the given [playorder] number.
  /// Page is a number from 1 to [BookNavigation.pages].
  /// Also page is a playorder value.
  ({BookPage page, String content}) getPage(
      BookMetadata metadata, int playorder);
}

/// Book metadata.
abstract base class BookMetadata {
  /// Book metadata.
  BookMetadata();

  /// Creates a book metadata from the given [json].
  factory BookMetadata.fromJson(Map<String, Object?> json) =>
      const _MetadataJSONDecoder().convert(json);

  /// Название книги.
  abstract final List<BookMetadataValue> title;

  /// Автор или создатель содержимого.
  abstract final List<BookMetadataValue> creator;

  /// Любое лицо или организация, которая внесло вклад,
  /// но не является основным автором.
  abstract final List<BookMetadataValue> contributor;

  /// Издатель книги.
  abstract final List<BookMetadataValue> publisher;

  /// Отношение к другим работам (например, часть серии).
  abstract final List<BookMetadataValue> relation;

  /// Тема или ключевые слова, описывающие книгу.
  abstract final List<BookMetadataValue> subject;

  /// Язык содержимого книги (обычно используется код ISO 639-1).
  abstract final List<BookMetadataValue> language;

  /// Уникальный идентификатор книги, например ISBN.
  abstract final List<BookMetadataValue> identifier;

  /// Краткое описание или аннотация содержимого книги.
  abstract final List<BookMetadataValue> description;

  /// Дата публикации или другая релевантная дата.
  abstract final List<BookMetadataValue> date;

  /// Тип ресурса (например, книга, изображение, таблица).
  abstract final List<BookMetadataValue> type;

  /// Формат ресурса (в данном контексте, это будет "application/epub+zip").
  abstract final List<BookMetadataValue> format;

  /// Источник произведения в случае, если это производное произведение.
  abstract final List<BookMetadataValue> source;

  /// Область действия работы
  /// (может быть географическим местоположением, временным периодом и т. д.).
  abstract final List<BookMetadataValue> coverage;

  /// Информация о правах (например, авторские права и лицензирование).
  abstract final List<BookMetadataValue> rights;

  /// Дополнительные метаданные.
  abstract final List<BookMetadataValue> meta;

  /// Book navigation.
  abstract final BookNavigation navigation;

  /// Converts this object to a JSON object.
  Map<String, Object?> toJson();
}

/// Book metadata value.
@immutable
class BookMetadataValue {
  /// Book metadata value.
  const BookMetadataValue(this.value, [this.meta]);

  /// Creates a book metadata value from the given [json].
  BookMetadataValue.fromJson(Map<String, Object?> json)
      : value = json['value']?.toString() ?? '',
        meta = switch (json['meta']) {
          Map<String, Object?> meta => meta,
          _ => null,
        };

  /// Book metadata value.
  final String value;

  /// Additional metadata for this value.
  final Map<String, Object?>? meta;

  /// Converts this object to a JSON object.
  Map<String, Object?> toJson() => <String, Object?>{
        'value': value,
        if (meta != null) 'meta': meta,
      };

  @override
  String toString() => value;
}

/// {@nodoc}
final class _MetadataJSONDecoder
    extends Converter<Map<String, Object?>, BookMetadata> {
  /// {@nodoc}
  const _MetadataJSONDecoder();

  @override
  BookMetadata convert(Map<String, Object?> input) {
    switch (input['@type']) {
      case 'epub':
        return const EpubMetadataJsonConverter().convert(input);
      default:
        throw ArgumentError.value(
          input,
          'input',
          'Unsupported book metadata type: ${input['@type']}.',
        );
    }
  }
}

/// Book navigation.
@immutable
abstract base class BookNavigation {
  /// Book navigation.
  const BookNavigation();

  /// Book navigation points tree (table of contents).
  abstract final List<BookPage> tableOfContents;

  /// Visits all child elements.
  void visitChildElements(void Function(BookPage page) visitor);

  /// Book navigation points list (reading order).
  List<BookPage> getReadingOrder();

  /// Get book pages count.
  int get pages;

  /// Converts this object to a JSON object.
  Map<String, Object?> toJson();
}

/// Book navigation point.
@immutable
abstract base class BookPage {
  /// Book navigation point.
  const BookPage();

  /// Label for the book navigation point.
  abstract final String label;

  /// Play order for the book navigation point.
  /// Page is a number from 1 to [BookNavigation.pages].
  abstract final int playorder;

  /// Has child elements.
  bool get hasChildren;

  /// Visits all child elements.
  void visitChildElements(void Function(BookPage page) visitor);

  /// Converts this object to a JSON object.
  Map<String, Object?> toJson();
}

/// Book image.
@immutable
abstract class BookResource {
  /// Book image.
  const BookResource();

  /// Book image path.
  /// e.g. "OEBPS/Images/cover.jpg", "OEBPS/Images/CoverDesign.jpg", etc.
  abstract final String path;

  /// Book image name.
  /// e.g. "cover.jpg", "CoverDesign.jpg", "image.png", etc.
  abstract final String name;

  /// Book image extension.
  /// e.g. ".jpg", ".png", ".gif", etc.
  abstract final String extension;

  /// Book image media type.
  /// e.g. "image/jpeg", "image/png", "image/gif", etc.
  abstract final String media;

  /// Book image size in bytes.
  abstract final int size;

  /// Book image bytes.
  abstract final Uint8List bytes;
}
