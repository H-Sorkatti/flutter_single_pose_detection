// ignore_for_file: prefer_final_fields, prefer_const_constructors

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;

class CameraApp extends StatefulWidget {
  const CameraApp({Key? key}) : super(key: key);

  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> with TickerProviderStateMixin {
  ValueNotifier<CameraFlashes> _switchFlash = ValueNotifier(CameraFlashes.NONE);
  ValueNotifier<Sensors> _sensor = ValueNotifier(Sensors.BACK);
  ValueNotifier<CaptureModes> _captureMode = ValueNotifier(CaptureModes.VIDEO);
  ValueNotifier<Size> _photoSize = ValueNotifier(Size(1080, 720));
  ValueNotifier<double> _zoom = ValueNotifier(0);
  ValueNotifier<bool> _audio = ValueNotifier(false);

  // Controllers
  PictureController _pictureController = new PictureController();
  VideoController _videoController = new VideoController();

  // _switchFlash.value = CameraFlashes.AUTO;
  // _captureMode.value = CaptureModes.VIDEO;

  ValueNotifier<List?> recognitionsList = ValueNotifier([]);
  bool _isDetecting = false;
  int counter = 0;

  Future<void> runModel(dynamic image) async {
    if (!_isDetecting && image != null) {
      print('################## inference method ###################');
      _isDetecting = true;
      await Tflite.detectObjectOnBinary(
        binary: image,
        model: 'SSDMobileNet',
        numResultsPerClass: 2,
        // numResults: 2,
        threshold: 0.4,
      ).then((value) {
        setState(() {
          _isDetecting = false;
          recognitionsList.value = value;
          print('###################### recognitionsList ##################');
          print(value.toString());
          print('###################### recognitionsList ##################');
        });
      }).onError((error, stackTrace) {
        _isDetecting = false;
        print('#################### error ##################');
        print('${error}');
        print('#################### error ##################');
      });
    }
  }

  Future<void> loadModel() async {
    Tflite.close();
    await Tflite.loadModel(
            model: "assets/tflite/ssd_mobilenet.tflite",
            labels: "assets/tflite/ssd_mobilenet_labelmap.txt",
            numThreads: 4,
            useGpuDelegate: true)
        .then((_) =>
            {print('###################### model loaded ###################')});
  }

  @override
  void initState() {
    super.initState();
    loadModel();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    // _photoSize.value = size;

    return Scaffold(
      appBar: AppBar(
        title: Text('CameraAwesome App'),
      ),
      body: SafeArea(
        child: Center(
          child: CameraAwesome(
            testMode: false,
            onPermissionsResult: (bool? result) {},
            selectDefaultSize: (availableSizes) => availableSizes[0],
            onCameraStarted: () {},
            onOrientationChanged: (newOrientation) {},
            zoom: _zoom,
            sensor: _sensor,
            photoSize: _photoSize,
            switchFlashMode: _switchFlash,
            captureMode: _captureMode,
            orientation: DeviceOrientation.portraitUp,
            enableAudio: _audio,
            imagesStreamBuilder: (Stream<Uint8List>? imageStream) {
              imageStream?.listen((event) {
                // print('######### Uint8List length: ${event.length} ##########');
                print(event.toString());
                // var _image = MemoryImage(event);
                // runModel(_image);
              });
            },
          ),
        ),
      ),
    );
  }
}
