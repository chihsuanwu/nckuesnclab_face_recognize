

import 'package:face_recognize/ImageHelper.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart';

import '../detectedDB.dart';
import '../faceDetectModel.dart';
import '../tfLiteModel.dart';


class DetectPerson {
  Face face;
  Image image;
  String? name;
  List feature;

  DetectPerson(this.face, this.image, this.name, this.feature);
}

class DetectResult {
  bool noPerson;
  List<DetectPerson>? unknownList;
  List<DetectPerson>? knownList;

  DetectResult(this.noPerson, {this.unknownList, this.knownList});
}


class DetectModel {

  TFLiteModel _tfLiteModel;

  FaceDetectModel _faceDetectModel = FaceDetectModel();

  DetectedDB _detectedDB = DetectedDB();

  bool isBusy = false;

  DetectModel(this._tfLiteModel) {
    _tfLiteModel.initialize();
    _detectedDB.loadData();
  }

  dispose() {
    _faceDetectModel.dispose();
  }

  reset() {

  }

  Future<DetectResult?> runFlow(Image image) async {
    if (!_tfLiteModel.isInitialized) return null;
    if (isBusy) return null;
    isBusy = true;

    final mlKitImage = ImageHelper.createInputImage(image);
    final result = await _detectFlowCore(mlKitImage, image);

    isBusy = false;

    return result;
  }

  Future<DetectResult> _detectFlowCore(InputImage mlKitImage, Image image) async {
    // Do MLKit's face detection.
    final faceList = await _faceDetectModel.detect(mlKitImage);

    // No face in image.
    if (faceList.isEmpty) return DetectResult(true);

    List<DetectPerson> unknownList = List.empty(growable: true);
    List<DetectPerson> knownList = List.empty(growable: true);

    // Process each face in detected face list
    for (final face in faceList) {
      final croppedImage = ImageHelper.cropFace(image, face);

      final feature = getFaceFeature(croppedImage);

      final person = _detectedDB.findClosestFace(feature);

      final data = DetectPerson(face, croppedImage, person?.name, feature);

      person != null ? knownList.add(data) : unknownList.add(data);
    }

    return DetectResult(false, unknownList: unknownList, knownList: knownList);
  }


  List<dynamic> getFaceFeature(Image image) {
    return _tfLiteModel.outputFaceFeature(image);
  }

  addFaceToDB(List<dynamic> feature, String name, Image image) {
    _detectedDB.addPerson(feature, name, image);
  }
}