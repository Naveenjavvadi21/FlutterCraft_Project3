import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  final UserProfile profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  final StorageService _storageService = StorageService();

  XFile? _pickedAvatarFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.displayName);
    _bioController = TextEditingController(text: widget.profile.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final file = await _storageService.pickImageFromGallery();
    if (file != null && mounted) {
      setState(() {
        _pickedAvatarFile = file;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    String? avatarUrl;
    if (_pickedAvatarFile != null) {
      avatarUrl = await _storageService.uploadImage(
        file: _pickedAvatarFile!,
        folder: AppConstants.avatarStoragePath,
        customFileName: '${widget.profile.uid}_avatar.jpg',
      );
    }

    if (!mounted) return;

    await context.read<AuthProvider>().updateCurrentProfile(
          displayName: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          avatarUrl: avatarUrl,
        );

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar selector
              Center(
                child: Stack(
                  children: [
                    if (_pickedAvatarFile != null)
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppTheme.primaryColor.withAlpha(40),
                        backgroundImage: kIsWeb
                            ? NetworkImage(_pickedAvatarFile!.path)
                            : FileImage(File(_pickedAvatarFile!.path)) as ImageProvider,
                      )
                    else
                      UserAvatar(
                        avatarUrl: widget.profile.avatarUrl,
                        name: widget.profile.displayName,
                        radius: 50,
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.primaryColor,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: _pickAvatar,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Display Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Display Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your display name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Username (Read-only)
              TextFormField(
                initialValue: '@${widget.profile.username}',
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Username (cannot be changed)',
                  prefixIcon: Icon(Icons.alternate_email),
                  enabled: false,
                ),
              ),
              const SizedBox(height: 16),

              // Bio
              TextFormField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Bio',
                  hintText: 'Write a short description about yourself...',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
