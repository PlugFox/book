import 'dart:convert';

import 'package:archive/archive.dart' as zip;
import 'package:book/src/book.dart';
import 'package:book/src/epub/epub.dart';
import 'package:book/src/exception.dart';
import 'package:meta/meta.dart';
import 'package:xml/xml.dart' as xml;

/// {@nodoc}
@internal
final class EpubMetadataExtractor {
  /// {@nodoc}
  const EpubMetadataExtractor();

  /// {@nodoc}
  static const String _kOpfNamespace = 'http://www.idpf.org/2007/opf';

  /// {@nodoc}
  EpubMetadata call({required zip.Archive archive, required String rootFile}) {
    final packageNode = _getPackageNode(archive: archive, rootFile: rootFile);
    final metadata = EpubMetadata();
    _addVersion(metadata, packageNode);
    _addMetadata(metadata, packageNode);
    _addManifest(metadata, packageNode);
    _addSpine(metadata, packageNode);
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
    String? id, media, href, properties;
    for (final e in elements) {
      if (e.name.local.trim().toLowerCase() != 'item') continue;
      id = e.getAttribute('id')?.trim().toLowerCase();
      media = e.getAttribute('media-type')?.trim().toLowerCase();
      href = e.getAttribute('href');
      properties = e.getAttribute('properties')?.trim().toLowerCase();
      if (id == null ||
          id.isEmpty ||
          media == null ||
          media.isEmpty ||
          href == null ||
          href.isEmpty) {
        continue;
      }
      metadata.epubManifest.items.add(EpubManifest$Item(
        id: id,
        media: media,
        href: href,
        properties: properties,
      ));
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
          xml.XmlElement packageNode, String root, [String? namespace]) =>
      packageNode
          .findElements('metadata', namespace: _kOpfNamespace)
          .whereType<xml.XmlElement>()
          .expand((elem) => elem.children)
          .whereType<xml.XmlElement>();
}
