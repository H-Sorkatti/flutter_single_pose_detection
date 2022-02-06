// ignore_for_file: prefer_const_constructors

import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_single_pose/tflite/classifier.dart';
import 'package:flutter_single_pose/tflite/recognition.dart';
import 'package:flutter_single_pose/utils/camera_view_singleton.dart';
import 'package:flutter_single_pose/utils/isolate_utils.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  late List cameras;
  late int selectedCameraIdx;
  late String imagePath;

  /// Instance of [Classifier]
  late Classifier classifier;

  /// Instance of [IsolateUtils]
  late IsolateUtils isolateUtils;

  /// List of [Recognitions]
  List<Recognition> _recognitions = [];
  static const double THRESHOLD = 0.3;
  bool _predicting = false;

  @override
  void initState() {
    super.initState();

    initStateAsync();
    // 1
    availableCameras().then((availableCameras) {
      cameras = availableCameras;
      if (cameras.isNotEmpty) {
        setState(() {
          // 2
          selectedCameraIdx = 1;
        });

        _initCameraController(cameras[selectedCameraIdx]).then((void v) {});
      } else {
        print("No camera available");
      }
    }).catchError((err) {
      // 3
      print('Error: $err.code\nError Message: $err.message');
    });
  }

  @override
  void dispose() {
    controller?.dispose();
  }

  Future _initCameraController(CameraDescription cameraDescription) async {
    if (controller != null) {
      await controller!.dispose();
    }

    // 3
    controller = CameraController(cameraDescription, ResolutionPreset.low);
    controller!.initialize().then((_) async {
      print('############### Controller init #######################');
      // Start ImageStream
      await controller!.startImageStream(onLatestImageAvailable);

      /// Screen Size
      Size previewSize = controller!.value.previewSize!;

      /// previewSize is size of raw input image to the model
      CameraViewSingleton.inputImageSize = previewSize;

      // the display width of image on screen is
      // same as screenWidth while maintaining the aspectRatio
      Size screenSize = MediaQuery.of(context).size;
      CameraViewSingleton.screenSize = screenSize;
      CameraViewSingleton.ratio = screenSize.width / previewSize.height;
    });
    // If the controller is updated then update the UI.
    // 4
    controller!.addListener(() {
      // 5
      if (mounted) {
        setState(() {});
      }

      if (controller!.value.hasError) {
        print('Camera error ${controller!.value.errorDescription}');
      }
    });

    // 6

    if (mounted) {
      setState(() {});
    }
  }

  void initStateAsync() async {
    // Spawn a new isolate
    isolateUtils = IsolateUtils();
    await isolateUtils.start();

    // Create an instance of classifier to load model and labels
    classifier = Classifier();

    // Initially predicting = false
    _predicting = false;
  }

  /// Callback to receive each frame [CameraImage] perform inference on it
  onLatestImageAvailable(CameraImage cameraImage) async {
    print("******************* Width: ${cameraImage.width} ***************");
    print("******************* Height: ${cameraImage.height} ***************");
    print(
        "******************* controller size: ${controller!.value.previewSize} ***************");
    if (classifier.interpreter != null) {
      // If previous inference has not completed then return
      if (_predicting) {
        return;
      }

      setState(() {
        _predicting = true;
      });

      var uiThreadTimeStart = DateTime.now().millisecondsSinceEpoch;

      // Data to be passed to inference  isolate
      var isolateData =
          IsolateData(cameraImage, classifier.interpreter.address);

      // We could have simply used the compute method as well however
      // it would be as in-efficient as we need to continuously passing data
      // to another isolate.

      /// perform inference in separate isolate
      Map<String, dynamic> inferenceResults = await inference(isolateData);

      setState(() {
        _recognitions = inferenceResults['recognitions']
            .where((Recognition value) => value.score >= THRESHOLD)
            .toList();
      });

      var uiThreadInferenceElapsedTime =
          DateTime.now().millisecondsSinceEpoch - uiThreadTimeStart;

      print('###############################################');
      print(
          '************** uiThreadInferenceElapsedTime: $uiThreadInferenceElapsedTime');
      // if (_recognitions.isNotEmpty)
      print('recognitions: ${_recognitions}');
      print('###############################################');

      setState(() {
        _predicting = false;
      });
    }
  }

  /// Runs inference in another isolate
  Future<Map<String, Object>> inference(IsolateData isolateData) async {
    ReceivePort responsePort = ReceivePort();
    isolateUtils.sendPort
        .send(isolateData..responsePort = responsePort.sendPort);
    var results = await responsePort.first;
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return _cameraPreviewWidget();
  }

  Widget _cameraPreviewWidget() {
    if (controller == null) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    if (controller != null &&
        controller!.value.isInitialized &&
        controller!.value.aspectRatio != null) {
      final size = MediaQuery.of(context).size;
      final sizeAr = MediaQuery.of(context).size.aspectRatio;
      final scale = 1 / (controller!.value.aspectRatio * sizeAr);
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Stack(
              children: [
                CameraPreview(controller!,
                    child: AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: Container(
                        child: true //_recognitions.isNotEmpty
                            ? CustomPaint(
                                painter: PointPainter(
                                  recognitions: [],
                                  scale: 1,
                                ),
                              )
                            : null,
                      ),
                    )),
              ],
            ),
            _cameraTogglesRowWidget()
          ],
        ),
      );
    }
    return Center(child: CircularProgressIndicator());
  }

  Widget _cameraTogglesRowWidget() {
    if (cameras == null || cameras.isEmpty) {
      return Spacer();
    }

    CameraDescription selectedCamera = cameras[selectedCameraIdx];
    CameraLensDirection lensDirection = selectedCamera.lensDirection;

    return Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
            onPressed: _onSwitchCamera,
            icon: Icon(_getCameraLensIcon(lensDirection)),
            label: Text(
                "${lensDirection.toString().substring(lensDirection.toString().indexOf('.') + 1)}")),
      ),
    );
  }

  IconData _getCameraLensIcon(CameraLensDirection direction) {
    switch (direction) {
      case CameraLensDirection.back:
        return Icons.camera_rear;
      case CameraLensDirection.front:
        return Icons.camera_front;
      case CameraLensDirection.external:
        return Icons.camera;
      default:
        return Icons.device_unknown;
    }
  }

  void _onSwitchCamera() {
    selectedCameraIdx =
        selectedCameraIdx < cameras.length - 1 ? selectedCameraIdx + 1 : 0;
    CameraDescription selectedCamera = cameras[selectedCameraIdx];
    _initCameraController(selectedCamera);
  }
}

class PointPainter extends CustomPainter {
  PointPainter({required List recognitions, required double scale}) {
    for (Recognition elm in recognitions) {
      Offset off = elm.location;
      points.add(off * scale);
    }
  }

  double scale = 1.0;
  List<Offset> points = [
    // Offset(0, 0),
    // Offset(2, 2),
    // Offset(4, 4),
    // Offset(64, 64),
    // Offset(128, 128),
    // Offset(256, 256),
    // Offset(512, 512),
    // Offset(,),
    Offset(350, 100),
    // Offset(410, 850),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    Paint painter = Paint()
      ..color = Color(0xFF64aa65)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawPoints(PointMode.points, points, painter);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
