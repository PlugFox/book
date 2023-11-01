import 'dart:collection';
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
    final metadata = EpubMetadata()..epubDirectory = p.dirname(rootFile);
    _addVersion(metadata, packageNode);
    _addMetadata(metadata, packageNode);
    _addManifest(metadata, packageNode);
    _addSpine(metadata, packageNode);
    _addNavigation(metadata, archive);
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
        value = BookMetadataValue(e.innerText, <String, Object?>{
          for (final attr in e.attributes)
            attr.name.local.trim().toLowerCase(): attr.value,
        });
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
            href = '${metadata.epubDirectory}/${attr.value}';
          default:
            meta ??= <String, Object?>{};
            meta[attr.name.local] = attr.value;
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

  static void _addNavigation(EpubMetadata metadata, zip.Archive archive) {
    final methods = <bool Function(EpubMetadata, zip.Archive)>[
      _addNavigationNavFile, // EPUB 2.0
      _addNavigationXHTML, // EPUB 3.0
      _addNavigationFallback, // Fallback
    ];
    for (var i = 0;
        i < methods.length && !methods[i](metadata, archive);
        i++) {}
  }

  static bool _addNavigationNavFile(
      EpubMetadata metadata, zip.Archive archive) {
    if (metadata.epubSpine.tableOfContents == null) return false;
    var navFileNcx = metadata.epubManifest.items
        .firstWhereOrNull(
            (item) => item.id == metadata.epubSpine.tableOfContents)
        ?.href;
    if (navFileNcx == null) return false;
    /* navFileNcx = '${metadata.epubDirectory}/$navFileNcx' */
    final basePath = p.dirname(navFileNcx);
    final navFileContent = switch (archive.files
        .firstWhereOrNull(
          (file) => file.name == navFileNcx,
        )
        ?.content) {
      String content => content,
      List<int> content => utf8.decode(content),
      _ => null,
    };
    if (navFileContent == null || navFileContent.isEmpty) return false;
    final navDocument = xml.XmlDocument.parse(navFileContent);
    final navNode =
        navDocument.findElements('ncx', namespace: _kNcxNamespace).firstOrNull;
    if (navNode == null) return false;

    // Нормализация путей к файлам внутри архива
    String normalizePath(String relativePath) => p
        .normalize(p.join(basePath, relativePath))
        .trim()
        .replaceAll(r'\', '/');

    // Рекурсивная функция для обхода navPoints
    final $playorders = <int>{};
    Iterable<_$EpubPage> parseNavPoints(
        Iterable<xml.XmlElement> navPoints) sync* {
      for (final navPoint in navPoints) {
        final label = navPoint
            .findElements('navLabel')
            .firstOrNull
            ?.findElements('text')
            .firstOrNull
            ?.innerText;

        final path =
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

        // Проверка наличия всех необходимых атрибутов
        if (path == null || playorder == null) continue;
        if ($playorders.contains(playorder)) continue;

        // Обработка вложенных элементов
        final inner = navPoint.findElements('navPoint').toList(growable: false);
        final children = inner.isEmpty
            ? null
            : parseNavPoints(inner).toList(growable: false);

        $playorders.add(playorder);
        final fragmentIdx = path.indexOf('#');
        final String src;
        final String? fragment;
        if (fragmentIdx == -1) {
          src = normalizePath(path);
          fragment = null;
        } else {
          src = normalizePath(path.substring(0, fragmentIdx));
          fragment = path.substring(fragmentIdx + 1);
        }

        yield _$EpubPage(
          id: id,
          src: src,
          fragment: fragment,
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

    final toc = _normalizePagesTree(parseNavPoints(navPoints));

    final metaEntities = navNode
        .findElements('head')
        .expand((node) => node.findElements('meta'))
        .map<(String?, Object?)>(
            (node) => (node.getAttribute('name'), node.getAttribute('content')))
        .where((e) => e.$1 != null)
        .cast<(String, Object?)>();

    final meta = UnmodifiableMapView<String, Object?>(<String, Object?>{
      for (final e in metaEntities) e.$1: e.$2,
    });

    final navigation = EpubNavigation(
      tableOfContents: toc,
      meta: meta,
    );

    // Assert that all navigation playorders are unique.
    assert(() {
      final playorders = $playorders.toSet();
      final total = playorders.length;
      var counter = 0;
      navigation.visitChildElements((point) {
        counter++;
        playorders.remove(point.playorder);
      });
      return counter == total;
    }(), 'Navigation playorders are not unique.');

    // Assert that all navigation files are in the archive.
    assert(() {
      final archiveFiles =
          archive.files.map<String>((file) => file.name).toSet();
      final files = <String>{};
      navigation.visitChildElements((point) {
        files.add(point.src);
      });

      final notFound = files.difference(archiveFiles);

      return notFound.isEmpty;
    }(), 'Navigation files not found in the archive.');

    metadata.navigation = navigation;
    return true;
  }

  static bool _addNavigationXHTML(EpubMetadata metadata, zip.Archive archive) {
    var navFilePath = metadata.epubManifest.items
        .firstWhereOrNull((item) => item.meta?['properties'] == 'nav')
        ?.href;
    if (navFilePath == null) return false;
    /* navFilePath = '${metadata.epubDirectory}/$navFilePath'; */
    final navFileContent = switch (archive.files
        .firstWhereOrNull(
          (file) => file.name == navFilePath,
        )
        ?.content) {
      String content => content,
      List<int> content => utf8.decode(content),
      _ => null,
    };
    if (navFileContent == null || navFileContent.isEmpty) return false;
    final navDocument = xml.XmlDocument.parse(navFileContent);
    final basePath = p.dirname(navFilePath);

    // Нормализация путей к файлам внутри архива
    String normalizePath(String relativePath) => p
        .normalize(p.join(basePath, relativePath))
        .trim()
        .replaceAll(r'\', '/');

    final navNode = navDocument
        .findAllElements('nav', namespace: '*')
        .where((node) => node.getAttribute('epub:type') == 'toc')
        .firstOrNull;

    if (navNode == null) return false;

    var $counter = 0; // Счетчик для playorder
    // Рекурсивная функция для обхода navPoints
    Iterable<_$EpubPage> parseNavPoints(
        Iterable<xml.XmlElement> navPoints) sync* {
      for (final navPoint in navPoints) {
        $counter++;
        final playorder = $counter;

        String? label, path, id = navPoint.getAttribute('id');
        final anchors = navPoint.findElements('a', namespace: '*');

        // Получение текста ссылки и пути к файлу
        for (final anchor in anchors) {
          label = anchor.innerText;
          path = anchor.getAttribute('href');
          if (path != null && path.isNotEmpty) break;
        }

        // Проверка наличия всех необходимых атрибутов
        if (path == null) continue;

        // Обработка вложенных элементов
        final inner = navPoint
            .findElements('ol', namespace: '*')
            .expand((elem) => elem.findElements('li', namespace: '*'))
            .toList(growable: false);
        final children = inner.isEmpty
            ? null
            : parseNavPoints(inner).toList(growable: false);

        // Формирование объекта EpubNavigation$Point
        final fragmentIdx = path.indexOf('#');
        final String src;
        final String? fragment;
        if (fragmentIdx == -1) {
          src = normalizePath(path);
          fragment = null;
        } else {
          src = normalizePath(path.substring(0, fragmentIdx));
          fragment = path.substring(fragmentIdx + 1);
        }

        yield _$EpubPage(
          id: id,
          src: src,
          fragment: fragment,
          label: label ?? '',
          playorder: playorder,
          children: children,
          meta: null,
        );
      }
    }

    final navPoints = navNode
        .findElements('ol', namespace: '*')
        .whereType<xml.XmlElement>()
        .expand((elem) => elem.findElements('li', namespace: '*'))
        .whereType<xml.XmlElement>();

    final toc = _normalizePagesTree(parseNavPoints(navPoints));

    final navigation = EpubNavigation(
      tableOfContents: toc,
      meta: null,
    );

    // Assert that all navigation files are in the archive.
    assert(() {
      final archiveFiles =
          archive.files.map<String>((file) => file.name).toSet();
      final files = <String>{};
      navigation.visitChildElements((point) {
        files.add(point.src);
      });

      final notFound = files.difference(archiveFiles);

      return notFound.isEmpty;
    }(), 'Navigation files not found in the archive.');

    metadata.navigation = navigation;
    return true;
  }

  static bool _addNavigationFallback(
          EpubMetadata metadata, zip.Archive archive) =>
      false;

  static List<EpubPage> _normalizePagesTree(Iterable<_$EpubPage> tree) {
    final src = tree.toList(growable: false);

    final allPages = <_$EpubPage>[];

    // Combine pages with the same src.
    // Src : <BookFragment>[]
    final fragments = <String, List<String>>{};

    {
      final ids = <String>{};
      final queue = Queue<_$EpubPage>.of(src);
      while (queue.isNotEmpty) {
        final page = queue.removeFirst();
        // Add id to the page if it is not unique.
        if (page.id == null || ids.contains(page.id)) {
          page.id = null;
        } else {
          ids.add(page.id ?? '');
        }
        allPages.add(page);
        // Add fragments to the src page.
        if (page.fragment case String fragment) {
          (fragments[page.src] ??= <String>[]).add(fragment);
        }
        if (page.children case List<_$EpubPage> children) {
          queue.addAll(children);
        }
      }
    }

    // Sort pages by playorder.
    allPages.sort((a, b) => a.playorder.compareTo(b.playorder));

    // Set playorder for all unique src pages.
    for (var i = 0; i < allPages.length; i++) {
      allPages[i].playorder = i + 1;
    }

    // TODO(plugfox): cache for src pages.
    // Add characters length to all pages.
    /* final file = archive.files.firstWhereOrNull((file) => file.name == src);
    if (file == null) continue;
    int length;
    {
      final content = switch (file.content) {
        String content => content,
        List<int> content => utf8.decode(content),
        _ => null,
      };
      if (content == null || content.isEmpty) continue;
      final document = xml.XmlDocument.parse(content);
      length = document.findAllElements('body').fold<int>(
            0,
            (prev, node) => prev + node.innerText.length,
          );
    } */

    EpubPage convert(_$EpubPage node) => EpubPage(
          id: node.id,
          src: node.src,
          label: node.label,
          playorder: node.playorder,
          length: node.length,
          fragment: node.fragment,
          children:
              node.children?.map<EpubPage>(convert).toList(growable: false),
          meta: node.meta,
        );

    return src.map<EpubPage>(convert).toList(growable: false);
  }
}

/// {@nodoc}
class _$EpubPage {
  /// {@nodoc}
  _$EpubPage({
    required this.src,
    required this.label,
    required this.playorder,
    this.id,
    this.fragment,
    this.children,
    this.meta,
  });

  /// {@nodoc}
  String? id;

  /// {@nodoc}
  String src;

  /// {@nodoc}
  String? fragment;

  /// {@nodoc}
  String label;

  /// {@nodoc}
  int playorder;

  /// {@nodoc}
  List<_$EpubPage>? children;

  /// {@nodoc}
  Map<String, Object?>? meta;

  /// {@nodoc}
  int length = 0;
}
