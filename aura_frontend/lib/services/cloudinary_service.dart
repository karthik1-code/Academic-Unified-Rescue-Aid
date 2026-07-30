import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Helper service to upload files directly to Cloudinary without requiring a backend signer.
/// This uses Cloudinary's Unsigned Upload API endpoint.
class CloudinaryService {
  /// REPLACE this with your actual Cloudinary Cloud Name
  static const String cloudName = "dyys1ys0i";

  /// REPLACE this with your actual Unsigned Upload Preset name
  static const String uploadPreset = "unsigned_preset_aura";

  /// Uploads binary file bytes (PDF, Image, etc.) directly to Cloudinary.
  /// Returns the secure HTTPS URL on success, or null on failure.
  static Future<String?> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      // PDF and DOCX files must use the 'raw' upload resource type in Cloudinary.
      // If uploading only images, you can change 'raw' to 'image'.
      final url = Uri.parse(
        "https://api.cloudinary.com/v1_1/$cloudName/raw/upload",
      );

      final request = http.MultipartRequest("POST", url);

      // 1. Add required fields
      request.fields['upload_preset'] = uploadPreset;
      // Replace non-alphanumeric characters in name to prevent Cloudinary errors
      final safePublicId = fileName
          .split('.')
          .first
          .replaceAll(RegExp(r'[^\w\s\-]'), '_');
      request.fields['public_id'] = safePublicId;

      // 2. Add the file multipart part
      final filePart = http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      );
      request.files.add(filePart);

      // 3. Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? secureUrl = data['secure_url'];
        print(" Cloudinary Upload Successful: $secureUrl");
        return secureUrl;
      } else {
        print(
          " Cloudinary Upload Failed (Status Code ${response.statusCode}):",
        );
        print(response.body);
        return null;
      }
    } catch (e) {
      print(" Cloudinary Upload Exception: $e");
      return null;
    }
  }
}
