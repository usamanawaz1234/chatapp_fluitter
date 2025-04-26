import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

import '../config/supabase_config.dart';

class MediaUploadService {
  static Future<String?> uploadImage(File file) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      await SupabaseConfig.supabase.storage
          .from('images')
          .upload('chatapp1/files/$fileName.jpg', file);

      final publicUrl = SupabaseConfig.supabase.storage
          .from('images')
          .getPublicUrl('chatapp1/files/$fileName.jpg');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image: $e');
    }
    return null;
  }

  static Future<String?> uploadVideo(File file) async {
    try {
      // Compress video before uploading
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
      );

      if (info?.file == null) return null;

      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      await SupabaseConfig.supabase.storage
          .from('videos')
          .upload('chatapp1/files/$fileName.mp4', info!.file!);

      final publicUrl = SupabaseConfig.supabase.storage
          .from('videos')
          .getPublicUrl('chatapp1/files/$fileName.mp4');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading video: $e');
    } finally {
      await VideoCompress.deleteAllCache();
    }
    return null;
  }
}
