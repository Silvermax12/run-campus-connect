import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/post_visibility.dart';
import 'create_post_controller.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  static const routeName = 'create-post';
  static const routePath = '/create-post';

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  XFile? _selectedImage;
  PostVisibility _visibility = PostVisibility.public;

  /// True when the user can submit — at least text or an image must be present.
  bool get _canPost =>
      _controller.text.trim().isNotEmpty || _selectedImage != null;

  @override
  void initState() {
    super.initState();
    // Rebuild whenever the user types so the Post button enables/disables.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1080,
    );
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
    });
  }

  /// Actually submits the post to Firestore.
  Future<void> _submit() async {
    final controller = ref.read(createPostControllerProvider.notifier);
    try {
      await controller.submit(
        content: _controller.text,
        visibility: _visibility,
        imageFile: _selectedImage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post shared successfully!')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// Shows a confirmation dialog, then submits if the user confirms.
  Future<void> _confirmAndSubmit() async {
    final feedLabel = _visibility.label; // 'Global', 'Faculty', or 'Department'
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Post'),
        content: Text(
            'This will be shared to your $feedLabel feed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(createPostControllerProvider);
    final isLoading = state.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: const InputDecoration(
                          hintText: "What's happening on campus?",
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(_selectedImage!.path),
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: isLoading ? null : _removeImage,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),

                    // ── Visibility selector ────────────────────────────────
                    Row(
                      children: [
                        const Icon(Icons.visibility_outlined, size: 20),
                        const SizedBox(width: 8),
                        const Text('Post to:'),
                        const SizedBox(width: 8),
                        DropdownButton<PostVisibility>(
                          value: _visibility,
                          underline: const SizedBox.shrink(),
                          borderRadius: BorderRadius.circular(12),
                          items: PostVisibility.values.map((v) {
                            return DropdownMenuItem(
                              value: v,
                              child: Text(v.label),
                            );
                          }).toList(),
                          onChanged: isLoading
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() => _visibility = value);
                                  }
                                },
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: isLoading ? null : _pickImage,
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Add image'),
                        ),
                        const Spacer(),
                        Text(
                          '${_controller.text.trim().length}/500',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Post button pinned to bottom-right ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed:
                        isLoading || !_canPost ? null : _confirmAndSubmit,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                    label: const Text('Post'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.runBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
