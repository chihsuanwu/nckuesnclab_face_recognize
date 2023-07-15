
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:face_recognize/ImageHelper.dart';

import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter/src/bindings/tensorflow_lite_bindings_generated.dart';

import 'package:image/image.dart' as imglib;

class TFLiteModel {
  late Interpreter _interpreter;

  // late Interpreter _ageInterpreter;


  late List _predictedData;
  List get predictedData => _predictedData;
  bool isInitialized = false;

  Future initialize() async {
    Delegate delegate;
    try {
      if (Platform.isAndroid) {
        delegate = GpuDelegateV2(
          options: GpuDelegateOptionsV2(
            isPrecisionLossAllowed: false,
            inferencePreference: TfLiteGpuInferenceUsage.TFLITE_GPU_INFERENCE_PREFERENCE_FAST_SINGLE_ANSWER,
            inferencePriority1: TfLiteGpuInferencePriority.TFLITE_GPU_INFERENCE_PRIORITY_MIN_LATENCY,
            inferencePriority2: TfLiteGpuInferencePriority.TFLITE_GPU_INFERENCE_PRIORITY_AUTO,
            inferencePriority3: TfLiteGpuInferencePriority.TFLITE_GPU_INFERENCE_PRIORITY_AUTO,
          )
        );
      } else if (Platform.isIOS) {
        delegate = GpuDelegate(
          options: GpuDelegateOptions(
              allowPrecisionLoss: true,
              waitType: TFLGpuDelegateWaitType.TFLGpuDelegateWaitTypeActive
          ),
        );
      } else {
        return;
      }
      var interpreterOptions = InterpreterOptions()..addDelegate(delegate);

      this._interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite',
          options: interpreterOptions);
      // this._interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');

      // this._ageInterpreter = await Interpreter.fromAsset('age_model.tflite',
      //     options: interpreterOptions);

      isInitialized = true;
    } catch (e) {
      print('Failed to load model.');
      print(e);
    }
  }

  // bool isBusy = false;

  List<double> outputFaceFeature(imglib.Image image, {bool predictAge = false}) {
    // if (isBusy) return;
    print("=========== IN ****** ===========");
    // final now = TimeOfDay.now()
    DateTime now = DateTime.now();
    print("=========== now $now ===========");


    List input = _preProcess(image);

    input = input.reshape([1, 112, 112, 3]);
    List output = List.generate(1, (index) => List.filled(256, 0));

    this._interpreter.run(input, output);

    print("=========== out size: ${output.shape} =============");

    List<double> reshaped = output.reshape([256]).cast<double>();

    // this._predictedData = List.from(output);
    print("=========== Success ===========");

    DateTime now2 = DateTime.now();
    print("=========== now $now2 ===========");

    if (predictAge) {
      // List ageOutput = List.generate(1, (index) => List.filled(1, 0));

      // List ageInput = _normalize(output);

      // this._ageInterpreter.run(ageInput, ageOutput);

      // print("=== age: $ageOutput");
    }

    return reshaped;

  }

  List<double> _normalize(List e) {
    int len = e.length;

    double sum = 0.0;
    for (int i = 0; i < len; i++) {
      sum += e[i];
    }

    double mean = sum / len;

    double sum2 = 0.0;

    for (int i = 0; i < len; i++) {
      sum2 += e[i] * e[i];//(e[i] - mean) * (e[i] - mean);
    }

    // sum2 /= len;
    double sigma = sqrt(sum2);

    List<double> result = new List.empty(growable: true);
    for (int i = 0; i < len; i++) {
      result.add(e[i]/sigma);
    }

    // sum = sqrt(sum);
    // print("distance: $sum ##########");
    return result;
  }

  List _preProcess(imglib.Image image) {
    Float32List imageAsList = ImageHelper.imageToByteListFloat32(image);
    return imageAsList;
  }
}
