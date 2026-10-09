import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/user_avatar.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textController = TextEditingController();
  final StorageService _storageService = StorageService();
  XFile? _selectedImage;
  bool _isPublishing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = source == ImageSource.gallery
        ? await _storageService.pickImageFromGallery()
        : await _storageService.pickImageFromCamera();

    if (file != null && mounted) {
      setState(() {
        _selectedImage = file;
      });
    }
  }

  Future<void> _publishPost() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text or select an image.')),
      );
      return;
    }

    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null) return;

    setState(() => _isPublishing = true);

    String? imageUrl;
    if (_selectedImage != null) {
      imageUrl = await _storageService.uploadImage(
        file: _selectedImage!,
        folder: AppConstants.postImagesStoragePath,
      );
    }

    if (!mounted) return;

    final success = await context.read<FeedProvider>().createPost(
          text: text,
          imageUrl: imageUrl,
          currentUser: currentUser,
        );

    if (mounted) {
      setState(() => _isPublishing = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post published successfully!'),
            backgroundColor: AppTheme.primaryColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to publish post.'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              onPressed: _isPublishing ? null : _publishPost,
              child: _isPublishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Post'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User avatar and name
              if (currentUser != null)
                Row(
                  children: [
                    UserAvatar(
                      avatarUrl: currentUser.avatarUrl,
                      name: currentUser.displayName,
                      radius: 22,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '@${currentUser.username}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              // Post Text Field
              TextField(
                controller: _textController,
                maxLines: 8,
                minLines: 4,
                decoration: const InputDecoration(
                  hintText: "What's happening? Share ideas, updates, or photos...",
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.transparent,
                ),
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),

              // Image Preview if picked
              if (_selectedImage != null) ...[
                const SizedBox(height: 16),
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: kIsWeb
                          ? Image.network(
                              _selectedImage!.path,
                              height: 280,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              File(_selectedImage!.path),
                              height: 280,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: IconButton.filled(
                        icon: const Icon(Icons.close, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withAlpha(180),
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedImage = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              const Divider(),

              // Image attachment buttons
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.image_outlined, color: AppTheme.primaryColor),
                    tooltip: 'Add from gallery',
                    onPressed: () => _pickImage(ImageSource.gallery),
                  ),
                  IconButton(
                    icon: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryColor),
                    tooltip: 'Take photo',
                    onPressed: () => _pickImage(ImageSource.camera),
                  ),
                  const Spacer(),
                  Text(
                    '${_textController.text.length} chars',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
