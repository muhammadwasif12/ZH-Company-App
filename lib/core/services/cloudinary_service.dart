import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Cloudinary service for image uploads (proof screenshots, etc.)
class CloudinaryService {
  CloudinaryService._();

  static String get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get _apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get _apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  /// Upload an image file to Cloudinary
  /// Returns the secure URL of the uploaded image
  static Future<String?> uploadImage(File file, {String? folder}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final folderPath = folder ?? 'beon_cosmetic/proofs';

      // Build signature string
      final signatureStr = 'folder=$folderPath&timestamp=$timestamp$_apiSecret';
      final signature = _generateSignature(signatureStr);

      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['folder'] = folderPath;
      request.fields['signature'] = signature;

      final mimeType = _getMimeType(file.path);
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: mimeType != null ? MediaType.parse(mimeType) : null,
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return jsonData['secure_url'] as String?;
      } else {
        throw Exception('Upload failed: ${jsonData['error']?['message']}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Upload from bytes (for desktop file picker)
  static Future<String?> uploadImageBytes(
    List<int> bytes,
    String fileName, {
    String? folder,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final folderPath = folder ?? 'beon_cosmetic/proofs';

      final signatureStr = 'folder=$folderPath&timestamp=$timestamp$_apiSecret';
      final signature = _generateSignature(signatureStr);

      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['api_key'] = _apiKey;
      request.fields['timestamp'] = timestamp.toString();
      request.fields['folder'] = folderPath;
      request.fields['signature'] = signature;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType('image', 'png'),
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return jsonData['secure_url'] as String?;
      } else {
        throw Exception('Upload failed: ${jsonData['error']?['message']}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static String _generateSignature(String input) {
    // SHA-1 signature for Cloudinary
    final bytes = utf8.encode(input);
    return sha1.convert(bytes).toString();
  }

  static String? _getMimeType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return null;
    }
  }

  /// Upload using unsigned preset (simpler, no signature needed)
  static Future<String?> uploadImageUnsigned(
    List<int> bytes,
    String fileName, {
    String uploadPreset = 'beon_cosmetic',
    String? folder,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['upload_preset'] = uploadPreset;
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType('image', 'png'),
        ),
      );

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = jsonDecode(responseData) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return jsonData['secure_url'] as String?;
      } else {
        throw Exception('Upload failed: ${jsonData['error']?['message']}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Removes an uploaded proof image using its Cloudinary delivery URL.
  /// A valid API key/secret is required; URLs outside this project's cloud are
  /// ignored so an order deletion can never target another Cloudinary account.
  static Future<bool> deleteImageByUrl(String? secureUrl) async {
    if (secureUrl == null || secureUrl.isEmpty ||
        _cloudName.isEmpty || _apiKey.isEmpty || _apiSecret.isEmpty) {
      return secureUrl == null || secureUrl.isEmpty;
    }
    try {
      final uri = Uri.tryParse(secureUrl);
      if (uri == null ||
          !uri.host.contains('res.cloudinary.com') ||
          !uri.path.contains(_cloudName)) {
        return false;
      }
      final parts = uri.pathSegments;
      final uploadIndex = parts.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 1 >= parts.length) return false;
      final assetParts = parts.sublist(uploadIndex + 1);
      if (assetParts.first.startsWith('v')) assetParts.removeAt(0);
      final joined = assetParts.join('/');
      final extensionIndex = joined.lastIndexOf('.');
      final publicId = extensionIndex > 0 ? joined.substring(0, extensionIndex) : joined;
      if (publicId.isEmpty) return false;

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final signature = _generateSignature(
        'invalidate=true&public_id=$publicId&timestamp=$timestamp$_apiSecret',
      );
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/destroy'),
        body: {
          'public_id': publicId,
          'invalidate': 'true',
          'timestamp': '$timestamp',
          'api_key': _apiKey,
          'signature': signature,
        },
      );
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['result'] == 'ok' || body['result'] == 'not found';
    } catch (_) {
      return false;
    }
  }
}
