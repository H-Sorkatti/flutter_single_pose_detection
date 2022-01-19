// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';

List<Widget> boundingBoxes(
    {required List? recognitionsList, required Size screenSize}) {
  if (recognitionsList == null) return [];

  double factorX = screenSize.width;
  double factorY = screenSize.height;

  return recognitionsList.map((result) {
    return Positioned(
      left: result["rect"]["x"] * factorX,
      top: result["rect"]["y"] * factorY,
      width: result["rect"]["w"] * factorX,
      height: result["rect"]["h"] * factorY,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            width: 2,
            color: Colors.red,
          ),
        ),
        child: Align(
          alignment: Alignment.topLeft,
          child: Container(
            color: Colors.red,
            child: Text(
              '${result['detectedClass']}: ${(result['confidenceInClass'] * 100).toStringAsFixed(0)}%',
              style: TextStyle(color: Colors.white, fontSize: 18.0),
            ),
          ),
        ),
      ),
    );
  }).toList();
}
