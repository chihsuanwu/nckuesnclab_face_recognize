import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_ml_kit/google_ml_kit.dart';


import 'package:image/image.dart';

/// Image helper class
class ImageHelper {

  // static InputImage createInputImage(Image image) {
  //   // final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
  //   // final InputImageRotation imageRotation = InputImageRotation.Rotation_0deg;
  //   // final InputImageFormat inputImageFormat = InputImageFormat.NV21;
  //   //
  //   // final inputImageData = InputImageData(
  //   //   size: imageSize,
  //   //   imageRotation: imageRotation,
  //   //   inputImageFormat: inputImageFormat,
  //   //   planeData: null,
  //   // );
  //   //
  //   // return InputImage.fromBytes(bytes: image.getBytes(), inputImageData: inputImageData);
  //
  //   final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
  //   final InputImageRotation imageRotation = InputImageRotation.rotation0deg;
  //   final InputImageFormat inputImageFormat = InputImageFormat.nv21;
  //
  //   final inputImageData = InputImageMetadata(
  //     size: imageSize,
  //     rotation: imageRotation,
  //     format: inputImageFormat,
  //     bytesPerRow: image,
  //   );
  //
  //   return InputImage.fromBytes(bytes: image.getBytes(), inputImageData: inputImageData);
  // }

  InputImage? inputImageFromCameraImage(CameraImage image) {
    // get image rotation
    // it is used in android to convert the InputImage from Dart to Java
    // `rotation` is not used in iOS to convert the InputImage from Dart to Obj-C
    // in both platforms `rotation` and `camera.lensDirection` can be used to compensate `x` and `y` coordinates on a canvas
    // final camera = cameras[_cameraIndex];
    // final sensorOrientation = camera.sensorOrientation;
    // InputImageRotation? rotation;
    // if (Platform.isIOS) {
    //   rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    // } else if (Platform.isAndroid) {
    //   var rotationCompensation =
    //   _orientations[_controller!.value.deviceOrientation];
    //   if (rotationCompensation == null) return null;
    //   if (camera.lensDirection == CameraLensDirection.front) {
    //     // front-facing
    //     rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
    //   } else {
    //     // back-facing
    //     rotationCompensation =
    //         (sensorOrientation - rotationCompensation + 360) % 360;
    //   }
    //   rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    // }
    // if (rotation == null) return null;

    final rotation = InputImageRotation.rotation90deg;

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) return null;

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }

  static Image cropFace(Image image, Face faceDetected, InputImageRotation rotation, {int outputSize = 112, double expandRatio = 0.1}) {
    double xExpand = faceDetected.boundingBox.width * expandRatio;
    double yExpand = faceDetected.boundingBox.height * expandRatio;
    double x = faceDetected.boundingBox.left - xExpand;
    double y = faceDetected.boundingBox.top - yExpand;
    double w = faceDetected.boundingBox.width + xExpand * 2;
    double h = faceDetected.boundingBox.height + yExpand * 2;

    final rotated = copyRotate(image, angle: rotation.rawValue);
    final croppedImage = copyCrop(rotated, x: x.round(), y: y.round(), width: w.round(), height: h.round());
    return copyResizeCropSquare(croppedImage, size: outputSize);
  }

  // static Image convertCameraImage(CameraImage image, {int sensorOrientation = 90}) {
  //   var img = _convertToImage(image)!;
  //   return copyRotate(img, angle: sensorOrientation);
  // }

  // static Image? _convertToImage(CameraImage image) {
  //   try {
  //     print("ImageHelper: " + image.format.group.name);
  //     switch (image.format.group) {
  //       case ImageFormatGroup.yuv420:
  //         return _convertYUV420(image);
  //       case ImageFormatGroup.bgra8888:
  //         return _convertBGRA8888(image);
  //       case ImageFormatGroup.jpeg:
  //         throw Exception("Image format not supported");
  //       case ImageFormatGroup.unknown:
  //         throw Exception("Image format not supported");
  //       case ImageFormatGroup.nv21:
  //         return _convertNV21(image);
  //     }
  //   } catch (e) {
  //     print("ImageHelper ERROR: " + e.toString());
  //   }
  //   return null;
  // }
  //
  // static Image _convertBGRA8888(CameraImage image) {
  //   return Image.fromBytes(
  //     width: image.width,
  //     height: image.height,
  //     bytes: image.planes[0].bytes.buffer,
  //     order: ChannelOrder.bgra,
  //   );
  // }

  // static Image _convertNV21(CameraImage image) {
  //   final width = image.width;
  //   final height = image.height;
  //
  //   Uint8List yuv420sp = image.planes[0].bytes;
  //   //int total = width * height;
  //   //Uint8List rgb = Uint8List(total);
  //   final outImg = Image(width: width, height: height); // default numChannels is 3
  //
  //   final int frameSize = width * height;
  //
  //   for (int j = 0, yp = 0; j < height; j++) {
  //     int uvp = frameSize + (j >> 1) * width, u = 0, v = 0;
  //     for (int i = 0; i < width; i++, yp++) {
  //       int y = (0xff & yuv420sp[yp]) - 16;
  //       if (y < 0) y = 0;
  //       if ((i & 1) == 0) {
  //         v = (0xff & yuv420sp[uvp++]) - 128;
  //         u = (0xff & yuv420sp[uvp++]) - 128;
  //       }
  //       int y1192 = 1192 * y;
  //       int r = (y1192 + 1634 * v);
  //       int g = (y1192 - 833 * v - 400 * u);
  //       int b = (y1192 + 2066 * u);
  //
  //       if (r < 0)
  //         r = 0;
  //       else if (r > 262143) r = 262143;
  //       if (g < 0)
  //         g = 0;
  //       else if (g > 262143) g = 262143;
  //       if (b < 0)
  //         b = 0;
  //       else if (b > 262143) b = 262143;
  //
  //       outImg.setPixelRgb(i, j, ((r << 6)  & 0xff0000) >> 16, ((g >> 2) & 0xff00) >> 8, (b >> 10) & 0xff);
  //     }
  //   }
  //   return outImg;
  // }
  //
  // static const shift = (0xFF << 24);
  // static Image _convertYUV420(CameraImage image) {
  //   final int width = image.width;
  //   final int height = image.height;
  //   final int uvRowStride = image.planes[1].bytesPerRow;
  //   final int uvPixelStride = image.planes[1].bytesPerPixel!;
  //   var img = Image(width: width, height: height);
  //   for (int x = 0; x < width; x++) { // Fill image buffer with plane[0] from YUV420_888
  //     for (int y = 0; y < height; y++) {
  //       final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
  //       // Use the row stride instead of the image width as some devices pad the image data,
  //       // and in those cases the image width != bytesPerRow. Using width will give you a destroyed image.
  //       final int index = y * uvRowStride + x;
  //       final yp = image.planes[0].bytes[index];
  //       final up = image.planes[1].bytes[uvIndex];
  //       final vp = image.planes[2].bytes[uvIndex];
  //       int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255).toInt();
  //       int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91).round().clamp(0, 255).toInt();
  //       int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255).toInt();
  //       img.setPixelRgb(x, y, r, g, b);
  //       // img.data[index] = shift | (b << 16) | (g << 8) | r;
  //     }
  //   }
  //
  //   return img;
  // }
  //

  Image decodeYUV420SP(InputImage image) {
    final width = image.metadata!.size.width.toInt();
    final height = image.metadata!.size.height.toInt();

    Uint8List yuv420sp = image.bytes!;
    //int total = width * height;
    //Uint8List rgb = Uint8List(total);
    final outImg = Image(width: width, height: height); // default numChannels is 3

    final int frameSize = width * height;

    for (int j = 0, yp = 0; j < height; j++) {
      int uvp = frameSize + (j >> 1) * width, u = 0, v = 0;
      for (int i = 0; i < width; i++, yp++) {
        int y = (0xff & yuv420sp[yp]) - 16;
        if (y < 0) y = 0;
        if ((i & 1) == 0) {
          v = (0xff & yuv420sp[uvp++]) - 128;
          u = (0xff & yuv420sp[uvp++]) - 128;
        }
        int y1192 = 1192 * y;
        int r = (y1192 + 1634 * v);
        int g = (y1192 - 833 * v - 400 * u);
        int b = (y1192 + 2066 * u);

        if (r < 0)
          r = 0;
        else if (r > 262143) r = 262143;
        if (g < 0)
          g = 0;
        else if (g > 262143) g = 262143;
        if (b < 0)
          b = 0;
        else if (b > 262143) b = 262143;

        outImg.setPixelRgb(i, j, ((r << 6)  & 0xff0000) >> 16, ((g >> 2) & 0xff00) >> 8, (b >> 10) & 0xff);

        /*rgb[yp] = 0xff000000 |
            ((r << 6) & 0xff0000) |
            ((g >> 2) & 0xff00) |
            ((b >> 10) & 0xff);*/
      }
    }
    return outImg;
  }

  static Float32List imageToByteListFloat32(Image image, {int size = 112}) {
    var convertedBytes = Float32List(1 * size * size * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;

    for (var i = 0; i < size; i++) {
      for (var j = 0; j < size; j++) {
        var pixel = image.getPixel(j, i);
        buffer[pixelIndex++] = (pixel.r - 128) / 128;
        buffer[pixelIndex++] = (pixel.g - 128) / 128;
        buffer[pixelIndex++] = (pixel.b - 128) / 128;
      }
    }
    return convertedBytes.buffer.asFloat32List();
  }
}
