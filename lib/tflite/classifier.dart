import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_camerawesome/tflite/recognition.dart';
import 'package:flutter_camerawesome/tflite/stats.dart';
import 'package:flutter_camerawesome/utils/camera_view_singleton.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:image/image.dart' as imageLib;

class Classifier {
  /// Instance of Interpreter
  late Interpreter _interpreter;

  // Gets the interpreter instance
  Interpreter get interpreter => _interpreter;

  static const String MODEL_FILE_NAME = "movenet_singlepose_lightning_3.tflite";

  /// Shapes of output tensors
  late List<List<int>> _outputShapes;

  /// Types of output tensors
  late List<TfLiteType> _outputTypes;

  /// Input size of image (height = width = 192)
  static const int INPUT_SIZE = 192;

  static const double THRESHOLD = 0.4;

  /// [ImageProcessor] used to pre-process the image
  late ImageProcessor imageProcessor;

  /// Padding the image to transform into square
  late int padSize;

  static const List<String> KEYPOINTS = [
    'nose',
    'left eye',
    'right eye',
    'left ear',
    'right ear',
    'left shoulder',
    'right shoulder',
    'left elbow',
    'right elbow',
    'left wrist',
    'right wrist',
    'left hip',
    'right hip',
    'left knee',
    'right knee',
    'left ankle',
    'right ankle'
  ];

  Classifier({Interpreter? interpreter}) {
    loadModel(interpreter: interpreter);
  }

  /// Loads interpreter from asset
  void loadModel({Interpreter? interpreter}) async {
    try {
      _interpreter = interpreter ??
          await Interpreter.fromAsset(
            MODEL_FILE_NAME,
            options: InterpreterOptions()..useNnApiForAndroid = true,
            // ..threads = 4,
          );

      //   var outputTensors = _interpreter.getOutputTensors();
      //   _outputShapes = [];
      //   _outputTypes = [];
      //   print('#############################################################');
      //   print(_interpreter.getOutputTensors());
      //   print('#############################################################');
      //   for (Tensor tensor in outputTensors) {
      //     _outputShapes.add(tensor.shape);
      //     _outputTypes.add(tensor.type);
      //   }
    } catch (e) {
      print("Error while creating interpreter: $e");
    }
  }

  // Pre-process the image
  TensorImage getProcessedImage(TensorImage inputImage) {
    padSize = max(inputImage.height, inputImage.width);

    // create ImageProcessor
    imageProcessor = ImageProcessorBuilder()
        // Padding the image
        .add(ResizeWithCropOrPadOp(padSize, padSize))
        // Resizing to input size
        .add(ResizeOp(INPUT_SIZE, INPUT_SIZE, ResizeMethod.BILINEAR))
        .build();

    inputImage = imageProcessor.process(inputImage);
    return inputImage;
  }

  /// Runs object detection on the input image
  dynamic predict(imageLib.Image image) {
    var predictStartTime = DateTime.now().millisecondsSinceEpoch;

    if (_interpreter == null) {
      if (kDebugMode) {
        print("Interpreter not initialized");
      }
      return null;
    }

    var preProcessStart = DateTime.now().millisecondsSinceEpoch;

    // Create TensorImage from image
    // TensorImage inputImage = TensorImage.fromImage(image);
    // _inputImage type TfLiteType.float32
    TensorImage inputImage = TensorImage(TfLiteType.float32);
    inputImage.loadImage(image);

    // Pre-process TensorImage
    inputImage = getProcessedImage(inputImage);

    var preProcessElapsedTime =
        DateTime.now().millisecondsSinceEpoch - preProcessStart;

    var outputList = List.filled(17 * 3, 0).reshape([1, 1, 17, 3]);
    TensorBuffer outputTensorBuffer = TensorBufferFloat(outputList.shape);

    Object output = outputTensorBuffer.buffer;

    // Inputs object for runForMultipleInputs
    // Use [TensorImage.buffer] or [TensorBuffer.buffer] to pass by reference
    Object input = inputImage.buffer;

    var inferenceTimeStart = DateTime.now().millisecondsSinceEpoch;

    // run inference
    // _interpreter.runForMultipleInputs(inputs, outputs);
    _interpreter.run(input, output);

    var inferenceTimeElapsed =
        DateTime.now().millisecondsSinceEpoch - inferenceTimeStart;

    List<Recognition> recognitions = [];

    for (int i = 0; i < 17; i++) {
      //   // Prediction score
      var score = outputTensorBuffer.getDoubleValue((3 * i) + 2);

      // Label string
      String label = KEYPOINTS.elementAt(i);

      double x = outputTensorBuffer.getDoubleValue((3 * i) + 1);
      double y = outputTensorBuffer.getDoubleValue(3 * i);
      Point location = Point(x, y);

      // Point tmp =
      // imageProcessor.inverseTransform(location, image.height, image.width);

      // var cam = CameraViewSingleton.inputImageSize;

      Point tmp = Point(x * image.width, y * image.height);

      Recognition recognition =
          Recognition(label, Offset(tmp.x.toDouble(), tmp.y.toDouble()), score);

      recognitions.add(recognition);
    }
    var predictElapsedTime =
        DateTime.now().millisecondsSinceEpoch - predictStartTime;

    return {
      "recognitions": recognitions,
      "stats": Stats(
        totalPredictTime: predictElapsedTime,
        inferenceTime: inferenceTimeElapsed,
        preProcessingTime: preProcessElapsedTime,
        totalElapsedTime: predictElapsedTime,
      )
    };
  }
}
