import 'dart:convert';

import 'package:archive/archive.dart' as zip;
import 'package:book/src/book.dart';
import 'package:book/src/epub/epub.dart';
import 'package:book/src/exception.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart' as xml;

/// {@nodoc}
@internal
final class EpubMetadataExtractor {
  /// {@nodoc}
  const EpubMetadataExtractor();

  /// {@nodoc}
  static const String _kOpfNamespace = 'http://www.idpf.org/2007/opf';
  static const String _kNcxNamespace = 'http://www.daisy.org/z3986/2005/ncx/';

  /// {@nodoc}
  EpubMetadata call({required zip.Archive archive, required String rootFile}) {
    final packageNode = _getPackageNode(archive: archive, rootFile: rootFile);
    final metadata = EpubMetadata();
    _addVersion(metadata, packageNode);
    _addMetadata(metadata, packageNode);
    _addManifest(metadata, packageNode);
    _addSpine(metadata, packageNode);
    final rootDir = p.dirname(rootFile);
    _addNavigation(metadata, archive, rootDir);
    // TODO(plugfox): navigation
    return metadata;
  }

  static xml.XmlElement _getPackageNode(
      {required zip.Archive archive, required String rootFile}) {
    final rootFileEntry = archive.files.firstWhere(
      (file) => file.name == rootFile,
      orElse: () => throw const BookException(
        'root_file_not_found',
        'Root file not found in the EPUB archive.',
      ),
    );
    final content = rootFileEntry.content;
    if (content is! List<int>) {
      throw BookException(
        'epub_invalid_container_file',
        'Parsing error: $rootFile file content is not a bytes.',
      );
    }
    final containerDocument = xml.XmlDocument.parse(utf8.decode(content));
    final packageNode = containerDocument
        .findElements('package', namespace: _kOpfNamespace)
        .firstOrNull;
    if (packageNode == null) {
      throw BookException(
        'epub_invalid_container_file',
        'Parsing error: $rootFile file content is not a valid XML.',
      );
    }
    return packageNode;
  }

  static void _addVersion(EpubMetadata metadata, xml.XmlElement packageNode) {
    final epubVersion =
        packageNode.getAttribute('version')?.trim().toLowerCase();
    if (epubVersion == null ||
        epubVersion.isEmpty ||
        !(epubVersion.startsWith('2.') || epubVersion.startsWith('3.'))) {
      throw const BookException(
        'epub_invalid_version',
        'Invalid epub version',
      );
    }
    metadata.epubVersion = epubVersion;
  }

  static void _addMetadata(EpubMetadata metadata, xml.XmlElement packageNode) {
    final elements =
        _elementsExtractor(packageNode, 'metadata', _kOpfNamespace);
    BookMetadataValue value;
    for (final e in elements) {
      if (e.attributes.isEmpty) {
        value = BookMetadataValue(e.innerText);
      } else {
        {
          value = BookMetadataValue(e.innerText, <String, Object?>{
            for (final attr in e.attributes)
              attr.name.local.trim().toLowerCase(): attr.value,
          });
        }
        switch (e.name.local.trim().toLowerCase()) {
          case 'title':
            metadata.title.add(value);
          case 'creator':
            metadata.creator.add(value);
          case 'subject':
            metadata.subject.add(value);
          case 'description':
            metadata.description.add(value);
          case 'publisher':
            metadata.publisher.add(value);
          case 'contributor':
            metadata.contributor.add(value);
          case 'date':
            metadata.date.add(value);
          case 'type':
            metadata.type.add(value);
          case 'format':
            metadata.format.add(value);
          case 'identifier':
            metadata.identifier.add(value);
          case 'source':
            metadata.source.add(value);
          case 'language':
            metadata.language.add(value);
          case 'relation':
            metadata.relation.add(value);
          case 'coverage':
            metadata.coverage.add(value);
          case 'rights':
            metadata.rights.add(value);
          case 'meta':
            metadata.meta.add(value);
        }
      }
    }
  }

  static void _addManifest(EpubMetadata metadata, xml.XmlElement packageNode) {
    final elements =
        _elementsExtractor(packageNode, 'manifest', _kOpfNamespace);
    String? id, media, href;
    for (final e in elements) {
      if (e.name.local.trim().toLowerCase() != 'item') continue;
      Map<String, Object?>? meta;
      for (final attr in e.attributes) {
        switch (attr.name.local.trim().toLowerCase()) {
          case 'id':
            id = attr.value.trim().toLowerCase();
          case 'media-type':
            media = attr.value.trim().toLowerCase();
          case 'href':
            href = attr.value;
          default:
            meta = <String, Object?>{
              for (final attr in e.attributes)
                attr.name.local.trim().toLowerCase(): attr.value,
            };
        }
      }
      if (id == null ||
          id.isEmpty ||
          media == null ||
          media.isEmpty ||
          href == null ||
          href.isEmpty) {
        continue;
      }
      metadata.epubManifest.items.add(
        EpubManifest$Item(
          id: id,
          media: media,
          href: href,
          meta: meta,
        ),
      );
    }
  }

  static void _addSpine(EpubMetadata metadata, xml.XmlElement packageNode) {
    final spineNode = packageNode
        .findElements('spine', namespace: _kOpfNamespace)
        .cast<xml.XmlElement>()
        .firstOrNull;

    final pageProgression = spineNode
        ?.getAttribute('page-progression-direction')
        ?.trim()
        .toLowerCase();
    final ltr = (pageProgression == null) ||
        pageProgression.trim().toLowerCase() == 'ltr';

    metadata.epubSpine
      ..tableOfContents = spineNode?.getAttribute('toc')?.trim().toLowerCase()
      ..ltr = ltr;

    for (final e in spineNode?.children.whereType<xml.XmlElement>() ??
        const <xml.XmlElement>[]) {
      final idref = e.getAttribute('idref');
      if (idref == null || idref.isEmpty) continue;
      final linear = e.getAttribute('linear')?.trim().toLowerCase() != 'no';
      metadata.epubSpine.items.add(EpubSpine$Item(
        idref: idref,
        linear: linear,
      ));
    }
  }

  static Iterable<xml.XmlElement> _elementsExtractor(
    xml.XmlElement packageNode,
    String root, [
    String? namespace,
  ]) =>
      packageNode
          .findElements(root, namespace: _kOpfNamespace)
          .whereType<xml.XmlElement>()
          .expand((elem) => elem.children)
          .whereType<xml.XmlElement>();

  static void _addNavigation(
      EpubMetadata metadata, zip.Archive archive, String rootDir) {
    final methods = <bool Function(EpubMetadata, zip.Archive, String)>[
      _addNavigationNavFile, // EPUB 2.0
      _addNavigationXHTML, // EPUB 3.0
      _addNavigationFallback, // Fallback
    ];
    for (var i = 0;
        i < methods.length && !methods[i](metadata, archive, rootDir);
        i++) {}
  }

  static bool _addNavigationNavFile(
      EpubMetadata metadata, zip.Archive archive, String rootDir) {
    if (metadata.epubSpine.tableOfContents == null) return false;
    var navFile = metadata.epubManifest.items
        .firstWhereOrNull(
            (item) => item.id == metadata.epubSpine.tableOfContents)
        ?.href;
    if (navFile == null) return false;
    navFile = '$rootDir/$navFile'.toLowerCase();
    final navFileContent = archive.files
        .firstWhereOrNull(
          (file) => file.name.toLowerCase() == navFile,
        )
        ?.content;
    if (navFileContent is! List<int>) return false;
    final navDocument = xml.XmlDocument.parse(utf8.decode(navFileContent));
    final navNode =
        navDocument.findElements('ncx', namespace: _kNcxNamespace).firstOrNull;
    if (navNode == null) return false;
    // Рекурсивная функция для обхода navPoints
    final $playorders = <int>{};
    Iterable<EpubNavigation$Point> parseNavPoints(
        Iterable<xml.XmlElement> navPoints) sync* {
      for (final navPoint in navPoints) {
        final label = navPoint
            .findElements('navLabel')
            .firstOrNull
            ?.findElements('text')
            .firstOrNull
            ?.innerText;

        // TODO(plugfox): normalize src to absolute path

        final src =
            navPoint.findElements('content').firstOrNull?.getAttribute('src');
        final meta = <String, String>{
          for (final attr in navPoint.attributes)
            attr.name.local.trim().toLowerCase(): attr.value,
        };
        final id = meta.remove('id');
        final playorder = switch (meta.remove('playorder')) {
          String v => int.tryParse(v),
          _ => null,
        };
        final children = switch (navPoint.findElements('navPoint')) {
          Iterable<xml.XmlElement> navPoints when navPoints.isNotEmpty =>
            parseNavPoints(navPoints).toList(),
          _ => null,
        };
        if (src == null || playorder == null || id == null) continue;
        if ($playorders.contains(playorder)) continue;
        $playorders.add(playorder);
        yield EpubNavigation$Point(
          id: id,
          src: src,
          label: label ?? '',
          playorder: playorder,
          children: children,
          meta: meta.isEmpty ? null : meta,
        );
      }
    }

    final navPoints = navNode
        .findElements('navMap', namespace: _kNcxNamespace)
        .whereType<xml.XmlElement>()
        .expand(
            (elem) => elem.findElements('navPoint', namespace: _kNcxNamespace))
        .whereType<xml.XmlElement>();

    final metaEntities = navNode
        .findElements('head')
        .expand((node) => node.findElements('meta'))
        .map<(String?, Object?)>(
            (node) => (node.getAttribute('name'), node.getAttribute('content')))
        .where((e) => e.$1 != null)
        .cast<(String, Object?)>();

    metadata.navigation = EpubNavigation(
      tableOfContents:
          UnmodifiableListView<EpubNavigation$Point>(parseNavPoints(navPoints)),
      meta: UnmodifiableMapView<String, Object?>(<String, Object?>{
        for (final e in metaEntities) e.$1: e.$2,
      }),
    );
    return true;
  }

  static bool _addNavigationXHTML(
      EpubMetadata metadata, zip.Archive archive, String rootDir) {
    // TODO(plugfox): navigation
    return false;
  }

  static bool _addNavigationFallback(
      EpubMetadata metadata, zip.Archive archive, String rootDir) {
    // TODO(plugfox): navigation
    return false;
  }
}
