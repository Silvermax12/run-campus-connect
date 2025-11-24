import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:riverpod/riverpod.dart' as rpd;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../profile/data/profile_repository.dart';
import '../../../profile/domain/user_profile.dart';
import '../../data/post_repository.dart';

part 'create_post_controller.g.dart';

@riverpod
class CreatePostController extends _$CreatePostController {
  @override
  rpd.AsyncValue<void> build() => const rpd.AsyncData(null);

  PostRepository get _repository => ref.read(postRepositoryProvider);

  Future<void> submit({required String content, XFile? imageFile}) async {
    if (content.trim().isEmpty && imageFile == null) {
      state = rpd.AsyncError(
        'Add some text or attach an image.',
        StackTrace.current,
      );
      return;
    }
    state = const rpd.AsyncLoading();
    try {
      final profile = await _loadProfile();
      await _repository.createPost(
        content: content,
        author: profile,
        imageFile: imageFile != null ? File(imageFile.path) : null,
      );
      state = const rpd.AsyncData(null);
    } catch (error, stackTrace) {
      state = rpd.AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<UserProfile> _loadProfile() async {
    final profile = await ref.read(currentUserProfileProvider.future);
    if (profile == null) {
      throw Exception('Complete your profile before posting.');
    }
    return profile;
  }
}
