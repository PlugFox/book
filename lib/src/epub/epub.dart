// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:archive/archive.dart' as zip;
import 'package:book/src/book.dart';
import 'package:book/src/epub/epub_metadata_extractor.dart';
import 'package:meta/meta.dart';

/// {@nodoc}
@internal
final class Epub extends Book {
  /// {@nodoc}
  const Epub({
    required this.hash,
    required zip.Archive archive,
    required String rootFile,
  })  : _archive = archive,
        _rootFile = rootFile;

  /// Book SHA-256 hash (hexadecimal string)
  @override
  final String hash;

  /// Book archive (zip)
  final zip.Archive _archive;

  /// Book root file path (OPF)
  /// e.g. OEBPS/content.opf or EPUB/package.opf
  final String _rootFile;

  @override
  BookMetadata getMetadata() => const EpubMetadataExtractor()(
        archive: _archive,
        rootFile: _rootFile,
      );

  @override
  int get hashCode => hash.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Epub && hash == other.hash;
}

/// {@nodoc}
@internal
final class EpubMetadata extends BookMetadata {
  /// {@nodoc}
  EpubMetadata();

  @override
  final List<BookMetadataValue> title = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> creator = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> contributor = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> publisher = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> relation = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> subject = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> language = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> identifier = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> description = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> date = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> type = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> format = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> source = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> coverage = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> rights = <BookMetadataValue>[];

  @override
  final List<BookMetadataValue> meta = <BookMetadataValue>[];

  /// Epub version
  /// {@nodoc}
  String epubVersion = '';

  /// Epub manifest
  /// {@nodoc}
  EpubManifest epubManifest = EpubManifest();

  /// Epub spine
  /// {@nodoc}
  EpubSpine epubSpine = EpubSpine();

  /// Epub navigation
  /// {@nodoc}
  EpubNavigation epubNavigation = EpubNavigation();

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub',
        '@version': epubVersion,
        '@manifest': epubManifest.toJson(),
        '@spine': epubSpine.toJson(),
        '@navigation': epubNavigation.toJson(),
        if (title.isNotEmpty) 'title': title,
        if (creator.isNotEmpty) 'creator': creator,
        if (contributor.isNotEmpty) 'contributor': contributor,
        if (publisher.isNotEmpty) 'publisher': publisher,
        if (relation.isNotEmpty) 'relation': relation,
        if (subject.isNotEmpty) 'subject': subject,
        if (language.isNotEmpty) 'language': language,
        if (identifier.isNotEmpty) 'identifier': identifier,
        if (description.isNotEmpty) 'description': description,
        if (date.isNotEmpty) 'date': date,
        if (type.isNotEmpty) 'type': type,
        if (format.isNotEmpty) 'format': format,
        if (source.isNotEmpty) 'source': source,
        if (coverage.isNotEmpty) 'coverage': coverage,
        if (rights.isNotEmpty) 'rights': rights,
        if (meta.isNotEmpty) 'meta': meta,
      };
}

/// {@nodoc}
@internal
final class EpubManifest {
  /// {@nodoc}
  EpubManifest({List<EpubManifest$Item>? items})
      : items = items ?? <EpubManifest$Item>[];

  /// Generate Class from Map<String, Object?>
  factory EpubManifest.fromJson(Map<String, Object?> json) => EpubManifest(
        items: switch (json['items']) {
          List<Object?> items => <EpubManifest$Item>[
              for (final item in items.whereType<Map<String, Object?>>())
                EpubManifest$Item.fromJson(item)
            ],
          _ => null,
        },
      );

  /// {@nodoc}
  final List<EpubManifest$Item> items;

  /// {@nodoc}
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub-manifest',
        'items': items
            .map<Map<String, Object?>>((item) => item.toJson())
            .toList(growable: false),
      };
}

/// {@nodoc}
@internal
final class EpubManifest$Item {
  /// {@nodoc}
  EpubManifest$Item({
    required this.id,
    required this.media,
    required this.href,
    Map<String, Object?>? meta,
  }) : meta = meta ?? <String, Object?>{};

  /// {@nodoc}
  factory EpubManifest$Item.fromJson(Map<String, Object?> json) =>
      EpubManifest$Item(
        id: json['id']?.toString() ?? '',
        media: json['media']?.toString() ?? '',
        href: json['href']?.toString() ?? '',
        meta: switch (json['meta']) {
          Map<String, Object?> meta => meta,
          _ => null,
        },
      );

  /// {@nodoc}
  final String id, media, href;

  /// Additional metadata for this value.
  /// {@nodoc}
  final Map<String, Object?> meta;

  /// {@nodoc}
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'media': media,
        'href': href,
        if (meta.isNotEmpty) 'meta': meta,
      };

  @override
  String toString() => href;
}

/// {@nodoc}
@internal
final class EpubSpine {
  /// {@nodoc}
  EpubSpine({
    this.tableOfContents,
    this.ltr,
    List<EpubSpine$Item>? items,
  }) : items = items ?? <EpubSpine$Item>[];

  /// Generate Class from Map<String, Object?>
  factory EpubSpine.fromJson(Map<String, Object?> json) => EpubSpine(
        ltr: switch (json['ltr']) {
          bool ltr => ltr,
          _ => null,
        },
        tableOfContents: json['toc']?.toString(),
        items: switch (json['items']) {
          List<Object?> items => <EpubSpine$Item>[
              for (final item in items.whereType<Map<String, Object?>>())
                EpubSpine$Item.fromJson(item)
            ],
          _ => null,
        },
      );

  /// {@nodoc}
  String? tableOfContents;

  /// {@nodoc}
  bool? ltr;

  /// {@nodoc}
  final List<EpubSpine$Item> items;

  /// {@nodoc}
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub-spine',
        if (tableOfContents != null) 'toc': tableOfContents,
        if (ltr != null) 'ltr': ltr,
        'items': items
            .map<Map<String, Object?>>((item) => item.toJson())
            .toList(growable: false),
      };
}

/// {@nodoc}
@internal
final class EpubSpine$Item {
  /// {@nodoc}
  EpubSpine$Item({
    required this.idref,
    required this.linear,
  });

  /// {@nodoc}
  factory EpubSpine$Item.fromJson(Map<String, Object?> json) => EpubSpine$Item(
        idref: json['idref']?.toString() ?? '',
        linear: json['linear'] == true,
      );

  /// {@nodoc}
  final String idref;

  /// {@nodoc}
  final bool linear;

  /// {@nodoc}
  Map<String, Object?> toJson() => <String, Object?>{
        'idref': idref,
        'linear': linear,
      };

  @override
  String toString() => idref;
}

/// {@nodoc}
@internal
final class EpubNavigation {
  /// {@nodoc}
  EpubNavigation({
    List<EpubNavigation$Point>? points,
    Map<String, Object?>? meta,
  })  : points = points ?? <EpubNavigation$Point>[],
        meta = meta ?? <String, Object?>{};

  /// {@nodoc}
  factory EpubNavigation.fromJson(Map<String, Object?> json) => EpubNavigation(
        points: switch (json['points']) {
          List<Object?> points => <EpubNavigation$Point>[
              for (final point in points.whereType<Map<String, Object?>>())
                EpubNavigation$Point.fromJson(point)
            ],
          _ => <EpubNavigation$Point>[],
        },
        meta: switch (json['meta']) {
          Map<String, Object?> meta => meta,
          _ => null,
        },
      );

  /// {@nodoc}
  final List<EpubNavigation$Point> points;

  /// Additional metadata for this value.
  /// {@nodoc}
  final Map<String, Object?> meta;

  /// {@nodoc}
  Map<String, Object?> toJson() => <String, Object?>{
        'points': points,
        if (meta.isNotEmpty) 'meta': meta,
      };
}

/// {@nodoc}
@internal
final class EpubNavigation$Point {
  /// {@nodoc}
  EpubNavigation$Point({
    required this.id,
    required this.src,
    required this.label,
    required this.playorder,
    this.children,
    Map<String, Object?>? meta,
  }) : meta = meta ?? <String, Object?>{};

  /// {@nodoc}
  factory EpubNavigation$Point.fromJson(Map<String, Object?> json) =>
      EpubNavigation$Point(
        id: json['id']?.toString() ?? '',
        src: json['src']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        playorder: switch (json['playorder']) {
          int playorder => playorder,
          String playorder => int.tryParse(playorder) ?? -1,
          _ => -1,
        },
        children: switch (json['children']) {
          List<Object?> children => <EpubNavigation$Point>[
              for (final child in children.whereType<Map<String, Object?>>())
                EpubNavigation$Point.fromJson(child)
            ],
          _ => null,
        },
        meta: switch (json['meta']) {
          Map<String, Object?> meta => meta,
          _ => null,
        },
      );

  /// {@nodoc}
  final String id;

  /// {@nodoc}
  final String src;

  /// {@nodoc}
  final String label;

  /// {@nodoc}
  final int playorder;

  /// {@nodoc}
  final List<EpubNavigation$Point>? children;

  /// Additional metadata for this value.
  /// {@nodoc}
  final Map<String, Object?> meta;

  /// {@nodoc}
  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'src': src,
        'label': label,
        'playorder': playorder,
        if (children != null) 'children': children,
        if (meta.isNotEmpty) 'meta': meta,
      };

  @override
  String toString() => label;
}
