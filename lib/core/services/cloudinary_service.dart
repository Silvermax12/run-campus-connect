import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/app_config.dart';
import '../config/cloudinary_config.dart';

part 'cloudinary_service.g.dart';

class CloudinaryUploadResult {
  const CloudinaryUploadResult({
    required this.secureUrl,
    required this.publicId,
    this.deleteToken,
  });

  final String secureUrl;
  final String publicId;
  final String? deleteToken;
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

  /// Uploads a post image via the unsigned upload preset.
  /// Returns [publicId] for server-side deletion (unsigned uploads cannot
  /// request a delete token from Cloudinary).
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
      final publicId = jsonResponse['public_id'] as String?;
      final deleteToken = jsonResponse['delete_token'] as String?;

      if (secureUrl == null || publicId == null) {
        throw Exception('Cloudinary response missing required fields.');
      }

      return CloudinaryUploadResult(
        secureUrl: secureUrl,
        publicId: publicId,
        deleteToken: deleteToken,
      );
    } catch (e) {
      throw Exception('Image upload failed: $e');
    }
  }

  /// Deletes an uploaded asset by [publicId] via the Vercel gateway.
  Future<void> deleteByPublicId({
    required String publicId,
    required String idToken,
  }) async {
    final url = Uri.parse('${AppConfig.vercelBaseUrl}/api/delete-cloudinary-asset');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'publicId': publicId}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to delete image: ${response.statusCode} ${response.body}',
      );
    }
  }

  /// Deletes an uploaded asset using a legacy `delete_token`, if present.
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
