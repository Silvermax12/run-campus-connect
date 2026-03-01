import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:riverpod/riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config/cloudinary_config.dart';

part 'cloudinary_service.g.dart';

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
}

@riverpod
CloudinaryService cloudinaryService(Ref ref) {
  return CloudinaryService();
}
