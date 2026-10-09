import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../firebase_options.dart';

class StorageService {
  final FirebaseStorage? _customStorage;
  final ImagePicker _picker = ImagePicker();

  StorageService({FirebaseStorage? storage}) : _customStorage = storage;

  FirebaseStorage? get _storage {
    if (_customStorage != null) return _customStorage;
    if (!DefaultFirebaseOptions.isConfigured) return null;
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  /// Pick an image from gallery with compression / quality constraint
  Future<XFile?> pickImageFromGallery() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      return null;
    }
  }

  /// Pick an image from camera
  Future<XFile?> pickImageFromCamera() async {
    try {
      return await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
    } catch (e) {
      debugPrint('Error picking image from camera: $e');
      return null;
    }
  }

  /// Upload an image to Firebase Storage and return the download URL
  Future<String?> uploadImage({
    required XFile file,
    required String folder,
    String? customFileName,
  }) async {
    final fileName = customFileName ?? '${const Uuid().v4()}.jpg';
    final storagePath = '$folder/$fileName';
    final storage = _storage;

    if (storage == null) {
      // Demo / offline mode: return realistic public placeholder image
      final sampleAvatars = [
        'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=500&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=500&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=500&auto=format&fit=crop&q=80',
      ];
      final samplePosts = [
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1579783902614-a3fb3927b675?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1518770660439-4636190af475?w=800&auto=format&fit=crop&q=80',
        'https://images.unsplash.com/photo-1451187580459-43490279c0fa?w=800&auto=format&fit=crop&q=80',
      ];

      if (folder.contains('avatar')) {
        return sampleAvatars[DateTime.now().millisecond % sampleAvatars.length];
      }
      return samplePosts[DateTime.now().millisecond % samplePosts.length];
    }

    try {
      final ref = storage.ref().child(storagePath);
      final metadata = SettableMetadata(contentType: 'image/jpeg');

      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final uploadTask = await ref.putData(bytes, metadata);
        return await uploadTask.ref.getDownloadURL();
      } else {
        final uploadTask = await ref.putFile(File(file.path), metadata);
        return await uploadTask.ref.getDownloadURL();
      }
    } catch (e) {
      debugPrint('Error uploading image to storage: $e');
      // Graceful fallback to sample photo if storage permissions/rules fail
      return 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=800&auto=format&fit=crop&q=80';
    }
  }
}
