import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/cloudinary_config.dart';

part 'cloudinary_service.g.dart';

class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.deleteToken,
    required this.publicId,
  });

  final String secureUrl;
  final String deleteToken;
  final String publicId;
}

class CloudinaryService {
  Future<String?> uploadFile(File file, {String folder = 'run_campus_posts'}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );

      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.fields['folder'] = folder;
      
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse['secure_url'] as String?;
      } else {
        throw Exception('Failed to upload image: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  /// Uploads an image and returns a `delete_token` that can later be used to
  /// delete it *without* an API secret (works with unsigned uploads).
  Future<CloudinaryUploadResult> uploadPostImage(
    File file, {
    String folder = 'run_campus_posts',
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadUrl),
      );

      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.fields['folder'] = folder;
      request.fields['return_delete_token'] = 'true';

      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to upload image: ${response.statusCode} ${response.body}',
        );
      }

      final jsonResponse = jsonDecode(response.body);
      final secureUrl = jsonResponse['secure_url'] as String?;
      final deleteToken = jsonResponse['delete_token'] as String?;
      final publicId = jsonResponse['public_id'] as String?;

      if (secureUrl == null || deleteToken == null || publicId == null) {
        throw Exception('Cloudinary response missing required fields.');
      }

      return CloudinaryUploadResult(
        secureUrl: secureUrl,
        deleteToken: deleteToken,
        publicId: publicId,
      );
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  /// Deletes an uploaded asset using a `delete_token` returned from upload.
  Future<void> deleteByToken(String deleteToken) async {
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/delete_by_token');

    final response = await http.post(
      url,
      body: {'token': deleteToken},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete image: ${response.statusCode} ${response.body}',
      );
    }
  }
}

@riverpod
CloudinaryService cloudinaryService(Ref ref) {
  return CloudinaryService();
}
