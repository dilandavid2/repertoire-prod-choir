import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class GestureController {
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final Function(double yaw)? onYaw;
  final Function(double pitch)? onPitch;

  CameraController? _cameraController;
  late FaceDetector _faceDetector;
  CameraDescription? _camera;

  bool _processing = false;
  DateTime _lastAction = DateTime.now();

  GestureController({
    required this.onLeft,
    required this.onRight,
    this.onYaw,
    this.onPitch,
  }) {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableClassification: false,
        enableTracking: true,
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<void> init() async {
    final cameras = await availableCameras();

    final frontCameras = cameras.where(
          (c) => c.lensDirection == CameraLensDirection.front,
    ).toList();

    if (frontCameras.isEmpty) {
      throw Exception('No se encontró cámara frontal');
    }

    _camera = frontCameras.first;

    _cameraController = CameraController(
      _camera!,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.nv21,
    );

    await _cameraController!.initialize();
    await _cameraController!.startImageStream(_processCameraImage);
  }

  Future<void> dispose() async {
    try {
      await _cameraController?.stopImageStream();
    } catch (_) {}
    await _cameraController?.dispose();
    await _faceDetector.close();
  }

  void _processCameraImage(CameraImage image) async {
    if (_processing) return;
    _processing = true;

    try {
      final inputImage = _convertToInputImage(image);
      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        final face = faces.first;
        final yaw = face.headEulerAngleY ?? 0;
        onYaw?.call(yaw);

        final pitch = face.headEulerAngleX ?? 0;
        onPitch?.call(pitch);

        debugPrint('Yaw: $yaw');

        final now = DateTime.now();
        final diff = now.difference(_lastAction).inMilliseconds;

        if (diff > 1500) {
          if (yaw > 20) {
            debugPrint('Derecha');
            _lastAction = now;
            onRight();
          } else if (yaw < -20) {
            debugPrint('Izquierda');
            _lastAction = now;
            onLeft();
          }
        }
      }
    } catch (e) {
      debugPrint('Error gesto: $e');
    } finally {
      _processing = false;
    }
  }

  InputImage _convertToInputImage(CameraImage image) {
    final camera = _camera;
    if (camera == null) {
      throw Exception('La cámara no está inicializada');
    }

    final rotation = _rotationFromSensor(camera.sensorOrientation);

    return InputImage.fromBytes(
      bytes: image.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  InputImageRotation _rotationFromSensor(int rotation) {
    switch (rotation) {
      case 90:
        return InputImageRotation.rotation90deg;
      case 180:
        return InputImageRotation.rotation180deg;
      case 270:
        return InputImageRotation.rotation270deg;
      case 0:
      default:
        return InputImageRotation.rotation0deg;
    }
  }
}