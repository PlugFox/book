// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:convert';
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
  BookResource? getCoverImage(final BookMetadata metadata) {
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
    return EpubResource(
      path: href,
      name: p.basename(href),
      extension: p.extension(href),
      media: media,
      size: content.length,
      bytes: bytes,
    );
  }

  @override
  String getPage(BookMetadata metadata, BookPage page) {
    if (metadata is! EpubMetadata)
      throw ArgumentError('metadata is not Epub Metadata');
    if (page is! EpubPage) throw ArgumentError('page is not Epub Page');
    final src = page.src;
    final file = _archive.files.firstWhereOrNull((file) => file.name == src);
    if (file == null) throw ArgumentError('File not found: $src');
    final content = file.content;
    switch (content) {
      case List<int> bytes:
        return utf8.decode(bytes);
      case String text:
        return text;
      default:
        throw ArgumentError('Unsupported content type: ${content.runtimeType}');
    }
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
    List<EpubPage>? tableOfContents,
    Map<String, Object?>? meta,
  })  : tableOfContents = tableOfContents ?? <EpubPage>[],
        meta = meta ?? <String, Object?>{};

  /// {@nodoc}
  factory EpubNavigation.fromJson(Map<String, Object?> json) => EpubNavigation(
        tableOfContents: switch (json['toc']) {
          List<Object?> points => UnmodifiableListView<EpubPage>(
              <EpubPage>[
                for (final point in points.whereType<Map<String, Object?>>())
                  EpubPage.fromJson(point)
              ],
            ),
          _ => const <EpubPage>[],
        },
        meta: switch (json['meta']) {
          Map<String, Object?> meta =>
            UnmodifiableMapView<String, Object?>(meta),
          _ => null,
        },
      );

  @override
  final List<EpubPage> tableOfContents;

  /// Additional metadata for this value.
  /// {@nodoc}
  final Map<String, Object?> meta;

  static final _$pages = Expando<int>('book#epub/nav/pages');

  @override
  int get pages => _$pages[this] ??= () {
        var count = 0;
        visitChildElements((page) {
          count++;
        });
        return count;
      }();

  @override
  void visitChildElements(covariant void Function(EpubPage page) visitor) {
    for (final point in tableOfContents) {
      visitor(point);
      point.visitChildElements(visitor);
    }
  }

  @override
  List<({BookPage page, List<String> fragments})> getReadingOrder() {
    // Get all pages from the table of contents in the correct order
    final readingOrder = <BookPage>[];
    visitChildElements(readingOrder.add);
    readingOrder.sort((a, b) => a.playorder.compareTo(b.playorder));

    // Remove duplicates (pages with the same src)
    final fragments = <String, List<String>>{};
    final output = <BookPage>[];
    for (final page in readingOrder) {
      if (!fragments.containsKey(page.src)) output.add(page);
      if (page.fragment case String fragment) {
        (fragments[page.src] ??= <String>[]).add(fragment);
      }
    }
    return <({BookPage page, List<String> fragments})>[
      for (final page in output)
        (
          page: page,
          fragments: fragments[page.src] ?? <String>[],
        )
    ];
  }

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub-nav',
        'toc': [
          if (tableOfContents case List<EpubPage> children)
            for (final child in children) child.toJson(),
        ],
        if (meta.isNotEmpty) 'meta': meta,
      };

  // TODO(plugfox): Tree structure
  /* @override
  String toString() => tableOfContents.toString(); */
}

/// {@nodoc}
@internal
@immutable
final class EpubPage extends BookPage implements Comparable<EpubPage> {
  /// {@nodoc}
  EpubPage({
    required this.id,
    required this.src,
    required this.label,
    required this.playorder,
    required this.length,
    this.fragment,
    this.children,
    Map<String, Object?>? meta,
  }) : meta = meta ?? <String, Object?>{};

  /// {@nodoc}
  factory EpubPage.fromJson(Map<String, Object?> json) => EpubPage(
        id: json['id']?.toString(),
        label: json['label']?.toString() ?? '',
        playorder: switch (json['number']) {
          int number => number,
          String number => int.tryParse(number) ?? -1,
          _ => -1,
        },
        src: json['src']?.toString() ?? '',
        length: switch (json['length']) {
          int length => length,
          String length => int.tryParse(length) ?? 0,
          _ => 0,
        },
        fragment: json['fragment']?.toString(),
        children: switch (json['children']) {
          List<Object?> children => <EpubPage>[
              for (final child in children.whereType<Map<String, Object?>>())
                EpubPage.fromJson(child)
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
  @override
  final String src;

  /// {@nodoc}
  @override
  final String label;

  /// {@nodoc}
  @override
  final int playorder;

  /// {@nodoc}
  @override
  final int length;

  /// {@nodoc}
  @override
  final String? fragment;

  @override
  bool get hasFragment => fragment != null;

  /// {@nodoc}
  @override
  final List<EpubPage>? children;

  @override
  bool get hasChildren => children?.isNotEmpty ?? false;

  /// Additional metadata for this value.
  /// {@nodoc}
  final Map<String, Object?> meta;

  @override
  void visitChildElements(covariant void Function(EpubPage page) visitor) {
    if (!hasChildren) return;
    for (final child in children!) {
      visitor(child);
      child.visitChildElements(visitor);
    }
  }

  @override
  int compareTo(covariant EpubPage other) =>
      playorder.compareTo(other.playorder);

  /// {@nodoc}
  @override
  Map<String, Object?> toJson() => <String, Object?>{
        '@type': 'epub-page',
        if (id != null) 'id': id,
        'label': label,
        'number': playorder,
        'src': src,
        'length': length,
        if (fragment != null) 'fragment': fragment,
        if (children != null)
          'children': [
            if (children case List<EpubPage> children)
              for (final child in children) child.toJson(),
          ],
        if (meta.isNotEmpty) 'meta': meta,
      };

  @override
  String toString() => label;
}

/// {@nodoc}
@internal
@immutable
final class EpubResource extends BookResource {
  /// {@nodoc}
  const EpubResource({
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
