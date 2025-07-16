import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:developer' as developer;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:image/image.dart' as img;

/// Utility class for cropping images based on bounding box coordinates
class ImageCropper {
  /// Crop an image based on bounding box coordinates
  ///
  /// [imageBytes] - The original image bytes
  /// [bbox] - Bounding box coordinates [x1, y1, x2, y2] where (x1,y1) is top-left and (x2,y2) is bottom-right
  /// Returns the cropped image bytes
  static Future<Uint8List> cropImage(
    Uint8List imageBytes,
    List<double> bbox,
  ) async {
    try {
      // Decode the image
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Failed to decode image');
      }

      safePrint(
        'ImageCropper: Original image size: ${image.width}x${image.height}',
      );
      safePrint('ImageCropper: Bbox coordinates: $bbox');

      // Try both absolute and normalized coordinates
      int x1, y1, x2, y2;

      // First try as absolute pixel coordinates
      x1 = bbox[0].round();
      y1 = bbox[1].round();
      x2 = bbox[2].round();
      y2 = bbox[3].round();

      safePrint(
        'ImageCropper: Trying absolute coordinates: x1=$x1, y1=$y1, x2=$x2, y2=$y2',
      );

      // If coordinates seem too large, try normalized coordinates
      if (x2 > image.width || y2 > image.height) {
        safePrint(
          'ImageCropper: Coordinates too large, trying normalized coordinates',
        );
        x1 = (bbox[0] * image.width).round();
        y1 = (bbox[1] * image.height).round();
        x2 = (bbox[2] * image.width).round();
        y2 = (bbox[3] * image.height).round();
        safePrint(
          'ImageCropper: Normalized coordinates: x1=$x1, y1=$y1, x2=$x2, y2=$y2',
        );
      }

      // Add 10-pixel margin around the crop area
      final margin = 10;
      final cropX = (x1 - margin).clamp(0, image.width - 1);
      final cropY = (y1 - margin).clamp(0, image.height - 1);
      final cropWidth = (x2 - x1 + 2 * margin).clamp(1, image.width - cropX);
      final cropHeight = (y2 - y1 + 2 * margin).clamp(1, image.height - cropY);

      safePrint(
        'ImageCropper: Final crop: x=$cropX, y=$cropY, w=$cropWidth, h=$cropHeight',
      );

      // Safety check: ensure we have a valid crop region
      if (cropWidth <= 0 || cropHeight <= 0) {
        safePrint(
          'ImageCropper: Invalid crop region, returning original image',
        );
        return imageBytes;
      }

      // Crop the image
      final croppedImage = img.copyCrop(
        image,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      safePrint(
        'ImageCropper: Cropped image size: ${croppedImage.width}x${croppedImage.height}',
      );

      // Encode the cropped image as PNG for consistent format
      final croppedBytes = img.encodePng(croppedImage);
      return Uint8List.fromList(croppedBytes);
    } catch (e) {
      safePrint('ImageCropper: Error cropping image: $e');
      throw Exception('Failed to crop image: $e');
    }
  }

  /// Save cropped image to a temporary file
  ///
  /// [croppedBytes] - The cropped image bytes
  /// [originalPath] - The original file path (used for extension)
  /// Returns the path to the saved cropped image
  static Future<String> saveCroppedImage(
    Uint8List croppedBytes,
    String originalPath,
  ) async {
    try {
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      await tempFile.writeAsBytes(croppedBytes);
      return tempFile.path;
    } catch (e) {
      throw Exception('Failed to save cropped image: $e');
    }
  }

  /// Converts any image format to PNG for consistent processing
  ///
  /// This method ensures all image processing, server communication, cropping,
  /// and final output use PNG format consistently throughout the KYC workflow.
  /// Camera captures in JPEG for efficiency, but all subsequent operations
  /// require PNG format for optimal quality and compatibility.
  ///
  /// [bytes] - The original image bytes in any format
  /// Returns PNG-formatted image bytes
  static Future<Uint8List> convertToPng(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Convert to PNG format for consistent processing
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } catch (e) {
      developer.log('ImageCropper: Error converting to PNG: $e');
      return bytes; // Return original if conversion fails
    }
  }
}
