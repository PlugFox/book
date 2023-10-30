// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:typed_data';

import 'package:archive/archive.dart' as zip;
import 'package:book/src/book.dart';
import 'package:book/src/epub/epub_metadata_extractor.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;

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
  BookImage? getCoverImage(final BookMetadata metadata) {
    assert(metadata is EpubMetadata, 'metadata is not EpubMetadata');
    if (metadata is! EpubMetadata) return null;
    EpubManifest$Item? coverItem;
    if (metadata.epubVersion.startsWith('2.')) {
      final itemId = metadata.meta
          .where((e) => e.meta?['name'] == 'cover')
          .map<Object?>((e) => e.meta?['content'])
          .whereType<String>()
          .firstOrNull;
      if (itemId == null) return null;
      coverItem = metadata.epubManifest.items.firstWhereOrNull(
        (item) => item.id == itemId,
      );
    } else if (metadata.epubVersion.startsWith('3.')) {
      coverItem = metadata.epubManifest.items.firstWhereOrNull(
        (item) => item.meta?['properties'] == 'cover-image',
      );
    } else {
      assert(false, 'Unsupported EPUB version');
    }
    if (coverItem == null) return null;
    final EpubManifest$Item(href: String href, media: String media) = coverItem;
    final file = _archive.files.firstWhereOrNull(
      (file) => file.name == href,
    );
    if (file == null) return null;
    final content = file.content;
    if (content is! List<int>) return null;
    final bytes = Uint8List.fromList(content);
    return EpubImage(
      path: href,
      name: p.basename(href),
      extension: p.extension(href),
      media: media,
      size: content.length,
      bytes: bytes,
    );
  }

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

  /// Epub root directory
  /// e.g. OEBPS/ or EPUB/
  /// {@nodoc}
  String epubDirectory = '';

  /// Epub version
  /// e.g. 2.0 or 3.0
  /// {@nodoc}
  String epubVersion = '';

  /// Epub manifest
  /// {@nodoc}
  EpubManifest epubManifest = EpubManifest();

  /// Epub spine
  /// {@nodoc}
  EpubSpine epubSpine = EpubSpine();

  @override
  EpubNavigation navigation = EpubNavigation();

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub',
        '@version': epubVersion,
        '@manifest': epubManifest.toJson(),
        '@spine': epubSpine.toJson(),
        'navigation': navigation.toJson(),
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
    required this.meta,
  });

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
  final Map<String, Object?>? meta;

  /// {@nodoc}
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub-manifest-item',
        'id': id,
        'media': media,
        'href': href,
        if (meta?.isNotEmpty ?? false) 'meta': meta,
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
        '@type': 'epub-spine-item',
        'idref': idref,
        'linear': linear,
      };

  @override
  String toString() => idref;
}

/// {@nodoc}
@internal
@immutable
final class EpubNavigation extends BookNavigation {
  /// {@nodoc}
  EpubNavigation({
    List<EpubNavigation$Point>? tableOfContents,
    Map<String, Object?>? meta,
  })  : tableOfContents = tableOfContents ?? <EpubNavigation$Point>[],
        meta = meta ?? <String, Object?>{};

  /// {@nodoc}
  factory EpubNavigation.fromJson(Map<String, Object?> json) => EpubNavigation(
        tableOfContents: switch (json['toc']) {
          List<Object?> points => UnmodifiableListView<EpubNavigation$Point>(
              <EpubNavigation$Point>[
                for (final point in points.whereType<Map<String, Object?>>())
                  EpubNavigation$Point.fromJson(point)
              ],
            ),
          _ => const <EpubNavigation$Point>[],
        },
        meta: switch (json['meta']) {
          Map<String, Object?> meta =>
            UnmodifiableMapView<String, Object?>(meta),
          _ => null,
        },
      );

  @override
  final List<EpubNavigation$Point> tableOfContents;

  /// Additional metadata for this value.
  /// {@nodoc}
  final Map<String, Object?> meta;

  @override
  void visitChildElements(
      covariant void Function(EpubNavigation$Point point) visitor) {
    for (final point in tableOfContents) {
      visitor(point);
      point.visitChildElements(visitor);
    }
  }

  @override
  List<BookNavigation$Point> getReadingOrder() {
    final readingOrder = <BookNavigation$Point>[];
    visitChildElements(readingOrder.add);
    return readingOrder..sort();
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub-nav',
        'toc': tableOfContents,
        if (meta.isNotEmpty) 'meta': meta,
      };
}

/// {@nodoc}
@internal
@immutable
final class EpubNavigation$Point extends BookNavigation$Point
    implements Comparable<EpubNavigation$Point> {
  /// {@nodoc}
  EpubNavigation$Point({
    required this.id,
    required this.src,
    required this.label,
    required this.playorder,
    this.fragment,
    this.children,
    Map<String, Object?>? meta,
  }) : meta = meta ?? <String, Object?>{};

  /// {@nodoc}
  factory EpubNavigation$Point.fromJson(Map<String, Object?> json) =>
      EpubNavigation$Point(
        id: json['id']?.toString(),
        label: json['label']?.toString() ?? '',
        playorder: switch (json['playorder']) {
          int playorder => playorder,
          String playorder => int.tryParse(playorder) ?? -1,
          _ => -1,
        },
        src: json['src']?.toString() ?? '',
        fragment: json['fragment']?.toString(),
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
  final String? id;

  /// {@nodoc}
  final String src;

  /// {@nodoc}
  final String? fragment;

  /// {@nodoc}
  @override
  final String label;

  /// {@nodoc}
  @override
  final int playorder;

  /// {@nodoc}
  final List<EpubNavigation$Point>? children;

  @override
  bool get hasChildren => children?.isNotEmpty ?? false;

  /// Additional metadata for this value.
  /// {@nodoc}
  final Map<String, Object?> meta;

  @override
  void visitChildElements(
      covariant void Function(EpubNavigation$Point point) visitor) {
    if (!hasChildren) return;
    for (final child in children!) {
      visitor(child);
      child.visitChildElements(visitor);
    }
  }

  @override
  int compareTo(covariant EpubNavigation$Point other) =>
      playorder.compareTo(other.playorder);

  /// {@nodoc}
  @override
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub-nav-point',
        if (id != null) 'id': id,
        'label': label,
        'playorder': playorder,
        'src': src,
        if (fragment != null) 'fragment': fragment,
        if (children != null) 'children': children,
        if (meta.isNotEmpty) 'meta': meta,
      };

  @override
  String toString() => label;
}

/// {@nodoc}
@internal
@immutable
final class EpubImage extends BookImage {
  /// {@nodoc}
  const EpubImage({
    required this.path,
    required this.name,
    required this.extension,
    required this.media,
    required this.size,
    required this.bytes,
  });

  @override
  final String path;

  @override
  final String name;

  @override
  final String extension;

  @override
  final String media;

  @override
  final int size;

  @override
  final Uint8List bytes;
}
