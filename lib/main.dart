// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_camerawesome/camera_app.dart';
import 'package:flutter_camerawesome/camera_awesome.dart';
import 'package:camera/camera.dart';

late List<CameraDescription> cameras;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await availableCameras().then((availableCameras) {
    cameras = availableCameras;
  });
  runApp(const HomePage(title: 'CameraAwesome App'));
}

class HomePage extends StatelessWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);
  final String title;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: title,
      home: Scaffold(
        body: SafeArea(
          child: CameraScreen(),
        ),
      ),
    );
  }
}
