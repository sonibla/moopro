import 'dart:typed_data';

import 'package:archive/archive.dart';

bool looksLikeZip(String filename) => filename.toLowerCase().endsWith('.zip');

const zipMaxTotalUncompressedBytes = 2 * 1024 * 1024 * 1024;

class ZipPasswordRequiredException implements Exception {}

class ZipWrongPasswordException implements Exception {}

class ZipTooLargeException implements Exception {
  final String message;
  const ZipTooLargeException(this.message);
  @override
  String toString() => message;
}

class ExtractedZipEntry {
  final String path;
  final Uint8List bytes;
  const ExtractedZipEntry({required this.path, required this.bytes});
}

List<ExtractedZipEntry> extractZip(Uint8List bytes, {String? password}) {
  final sanitized = _sanitizeLocalExtraFields(bytes);
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(sanitized, password: password);
  } catch (_) {
    if (password == null) throw ZipPasswordRequiredException();
    throw ZipWrongPasswordException();
  }

  final entries = <ExtractedZipEntry>[];
  var totalBytes = 0;
  for (final entry in archive.files) {
    if (entry.isDirectory) continue;

    Uint8List content;
    try {
      content = entry.content;
    } catch (_) {
      if (password == null) throw ZipPasswordRequiredException();
      throw ZipWrongPasswordException();
    }

    final storedCrc = entry.crc32;
    if (storedCrc != null && storedCrc != 0 && getCrc32(content) != storedCrc) {
      if (password == null) throw ZipPasswordRequiredException();
      throw ZipWrongPasswordException();
    }

    totalBytes += content.length;
    if (totalBytes > zipMaxTotalUncompressedBytes) {
      throw const ZipTooLargeException(
        'This archive is too large to import at once.',
      );
    }
    entries.add(ExtractedZipEntry(path: entry.name, bytes: content));
  }
  return entries;
}

const _eocdSignature = 0x06054b50;
const _eocdFixedSize = 22;
const _centralHeaderSignature = 0x02014b50;
const _centralHeaderFixedSize = 46;
const _localHeaderSignature = 0x04034b50;
const _localHeaderFixedSize = 30;
const _aesExtraFieldId = 0x9901;
const _zip64Sentinel16 = 0xffff;
const _zip64Sentinel32 = 0xffffffff;

Uint8List _sanitizeLocalExtraFields(Uint8List original) {
  if (original.length < _eocdFixedSize) return original;
  final bytes = Uint8List.fromList(original);
  final view = ByteData.sublistView(bytes);

  var eocdPos = -1;
  for (var i = bytes.length - _eocdFixedSize; i >= 0; i--) {
    if (view.getUint32(i, Endian.little) == _eocdSignature) {
      eocdPos = i;
      break;
    }
  }
  if (eocdPos < 0) return original;

  final totalEntries = view.getUint16(eocdPos + 10, Endian.little);
  final centralDirOffset = view.getUint32(eocdPos + 16, Endian.little);
  if (totalEntries == _zip64Sentinel16 ||
      centralDirOffset == _zip64Sentinel32) {
    return original;
  }

  var pos = centralDirOffset;
  for (var i = 0; i < totalEntries; i++) {
    if (pos + _centralHeaderFixedSize > bytes.length ||
        view.getUint32(pos, Endian.little) != _centralHeaderSignature) {
      return original;
    }
    final flags = view.getUint16(pos + 8, Endian.little);
    final fnLen = view.getUint16(pos + 28, Endian.little);
    final exLen = view.getUint16(pos + 30, Endian.little);
    final commentLen = view.getUint16(pos + 32, Endian.little);
    final localHeaderOffset = view.getUint32(pos + 42, Endian.little);

    if ((flags & 0x1) != 0 && localHeaderOffset != _zip64Sentinel32) {
      _sanitizeOneLocalExtraField(bytes, view, localHeaderOffset);
    }

    pos += _centralHeaderFixedSize + fnLen + exLen + commentLen;
  }

  return bytes;
}

void _sanitizeOneLocalExtraField(
  Uint8List bytes,
  ByteData view,
  int localHeaderOffset,
) {
  if (localHeaderOffset + _localHeaderFixedSize > bytes.length) return;
  if (view.getUint32(localHeaderOffset, Endian.little) !=
      _localHeaderSignature) {
    return;
  }

  final fnLen = view.getUint16(localHeaderOffset + 26, Endian.little);
  final exLen = view.getUint16(localHeaderOffset + 28, Endian.little);
  if (exLen <= 2) return;

  final extraStart = localHeaderOffset + _localHeaderFixedSize + fnLen;
  final extraEnd = extraStart + exLen;
  if (extraEnd > bytes.length) return;

  List<int>? aesRecord;
  var p = extraStart;
  while (p + 4 <= extraEnd) {
    final id = view.getUint16(p, Endian.little);
    final size = view.getUint16(p + 2, Endian.little);
    if (p + 4 + size > extraEnd) break;
    if (id == _aesExtraFieldId) {
      aesRecord = bytes.sublist(p, p + 4 + size);
      break;
    }
    p += 4 + size;
  }

  bytes.fillRange(extraStart, extraEnd, 0);
  if (aesRecord != null) {
    bytes.setRange(extraStart, extraStart + aesRecord.length, aesRecord);
  }
}
