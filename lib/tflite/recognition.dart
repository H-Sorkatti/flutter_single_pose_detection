import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter_single_pose/utils/camera_view_singleton.dart';

/// Represents the recognition output from the model
class Recognition {
  late String _label;

  late Offset _location;

  /// Confidence [0.0, 1.0]
  late double _score;

  Recognition(this._label, this._location, this._score);

  String get label => _label;

  Offset get location => _location;

  double get score => _score;

  /// Returns keypoints locations corresponding to the
  /// displayed image on screen.
  ///
  /// This is the actual locations where points are rendered on
  /// the screen.
  Offset get renderLocation {
    // ratioX = screenWidth / imageInputWidth
    // ratioY = ratioX if image fits screenWidth with aspectRatio = constant

    double ratioX = CameraViewSingleton.ratio;
    double ratioY = ratioX;

    double transX = max(0.1, location.dx * ratioX);
    double transY = max(0.1, location.dy * ratioY);

    Offset transformedPoint = Offset(transX, transY);
    return transformedPoint;
  }

  @override
  String toString() {
    return 'Recognition(label: $label, location: $location, score: $score)';
  }
}
