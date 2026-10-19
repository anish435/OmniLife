import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Biggest receipt file accepted. Matches `storage.rules`.
const maxReceiptBytes = 10 * 1024 * 1024;

/// Storage path for a receipt: `receipts/{uid}/{fileName}`, the only place
/// `storage.rules` lets that user write to. The file name is cleaned so it
/// cannot climb out of the folder.
String receiptStoragePath(String uid, String id, String originalName) {
  final cleaned = originalName
      .split(RegExp(r'[\\/]'))
      .last
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  final name = cleaned.isEmpty ? 'receipt' : cleaned;
  return 'receipts/$uid/${id}_$name';
}

/// `image/...` or `application/pdf` from a file name, or null when the
/// type is not allowed for receipts.
String? receiptContentType(String fileName, {String? reported}) {
  final r = reported?.toLowerCase();
  if (r != null && (r.startsWith('image/') || r == 'application/pdf')) {
    return r;
  }
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'heic':
      return 'image/heic';
    case 'gif':
      return 'image/gif';
    case 'pdf':
      return 'application/pdf';
  }
  return null;
}

/// Uploads a receipt and returns where to download it from.
abstract class ReceiptUploader {
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });
}

class FirebaseReceiptUploader implements ReceiptUploader {
  const FirebaseReceiptUploader();

  @override
  Future<String> upload({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final ref = FirebaseStorage.instance.ref(path);
    final snapshot = await ref.putData(
      bytes,
      SettableMetadata(contentType: contentType),
    );
    return snapshot.ref.getDownloadURL();
  }
}
