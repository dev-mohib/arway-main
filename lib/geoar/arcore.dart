import 'dart:async';
import 'dart:math';
import 'package:arway/geoar/ar_view.dart';
import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';

import 'info.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vector;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class ArCoreMain extends StatefulWidget {
  @override
  _ArCoreMainState createState() => _ArCoreMainState();
}

enum WidgetDistance { ready, navigating }
enum WidgetCompass { scanning, directing }
enum TtsState { playing, stopped }

class _ArCoreMainState extends State<ArCoreMain> {
  WidgetDistance situationDistance = WidgetDistance.navigating;
  WidgetCompass situationCompass = WidgetCompass.directing;

  ARKitController arkitController;
  bool anchorWasFound = false;
  FlutterTts flutterTts;
  int _clearDirection = 0;
  double distance = 0;
  int _distance = 0;
  double targetDegree = 0;
  Timer timer;
  TtsState ttsState = TtsState.stopped;
  ArCoreController arCoreController;

  double _facultypositionlat = 31.415273;
  double _facultypositionlong = 74.246618;

  //calculation formula of angel between 2 different points
  double angleFromCoordinate(
      double lat1, double long1, double lat2, double long2) {
    double dLon = (long2 - long1);

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    double brng = atan2(y, x);

    brng = vector.degrees(brng);
    brng = (brng + 360) % 360;
    //brng = 360 - brng; //remove to make clockwise
    return brng;
  }

  Future _speak() async {
    await flutterTts.setVolume(1.0);
    await flutterTts.setSpeechRate(0.4);
    await flutterTts.setPitch(1.0);

    if (_distance != 0) {
      var result = await flutterTts.speak(
          'Object $_distance meters dooor hai.'); //'Distance of placed object is $_distance meters'
      if (result == 1) setState(() => ttsState = TtsState.playing);
    }
  }

  //device compass
  void calculateDegree() {
    // direction type = double
    FlutterCompass.events.listen((dynamic direction) {
      // showMsg('Getting angle for $direction');
      setState(() {
        if (targetDegree != null && direction != null) {
          _clearDirection =
              targetDegree.truncate() - direction?.heading?.truncate();
        }
      });
    });
  }

  //distance between faculty and device coordinates
  void _getlocation() async {
    //if you want to check location service permissions use checkGeolocationPermissionStatus method
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    distance = await Geolocator.distanceBetween(position.latitude,
        position.longitude, _facultypositionlat, _facultypositionlong);

    targetDegree = angleFromCoordinate(position.latitude, position.longitude,
        _facultypositionlat, _facultypositionlong);
    calculateDegree();
  }

  @override
  void initState() {
    super.initState();
    _getlocation(); //first run
    flutterTts = FlutterTts();
    timer = Timer.periodic(Duration(seconds: 7), (timer) {
      _getlocation();
      if (distance < 50 && distance != 0 && distance != null) {
        setState(() {
          situationDistance = WidgetDistance.ready;
          situationCompass = WidgetCompass.scanning;
        });
      } else {
        setState(() {
          _distance = distance.truncate();
          situationDistance = WidgetDistance.navigating;
          situationCompass = WidgetCompass.directing;
        });
        _speak(); //Speak the distance
      }
    });
  }

  @override
  void dispose() {
    arkitController?.dispose();
    arCoreController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text('Target $_clearDirection'),
        actions: <Widget>[
          IconButton(
              icon: Icon(Icons.help),
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (BuildContext context) => CustomDialog());
              }),
          IconButton(
              onPressed: () async {
                Position position = await Geolocator.getCurrentPosition(
                    desiredAccuracy: LocationAccuracy.high);
                setState(() {
                  _facultypositionlat = position.latitude;
                  _facultypositionlong = position.longitude;
                });
              },
              icon: Icon(Icons.location_on))
        ],
        flexibleSpace: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                Color.fromARGB(190, 207, 37, 7),
                Colors.transparent
              ])),
        ),
      ),
      body: distanceProvider(),
      floatingActionButton: compassProvider());

// WidgetDistance.ready & if ? distance < 50
  Widget readyWidget() {
    return Container(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArCoreView(
            onArCoreViewCreated: (controler) =>
                _onArCoreViewCreated(controler, Colors.green),
            enableTapRecognizer: true,
          ),
          anchorWasFound
              ? Container()
              : Column(
                  //do something here...
                  ),
        ],
      ),
    );
  }

// WidgetCompass.scanning & if distance < 50
  Widget scanningWidget() {
    return FloatingActionButton(
      backgroundColor: Colors.blue,
      onPressed: null,
      child: Ink(
          decoration: const ShapeDecoration(
            color: Colors.lightBlue,
            shape: CircleBorder(),
          ),
          child: IconButton(
            icon: Icon(Icons.remove_red_eye),
            color: Colors.white,
            onPressed: () {},
          )),
    );
  }

// WidgetDistance.navigating & else ? distance < 50
  Widget navigateWidget() {
    return Container(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ArCoreView(
            onArCoreViewCreated: (controler) =>
                _onArCoreViewCreated(controler, Colors.red),
            enableTapRecognizer: true,
            enableUpdateListener: true,
          ),
          anchorWasFound
              ? Container()
              : Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(' Object is : $_distance m away.',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              backgroundColor: Colors.blueGrey,
                              color: Colors.white)),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

// WidgetCompass.directing && else ? distance < 50
  Widget directingWidget() {
    return FloatingActionButton(
      backgroundColor: Colors.blue,
      onPressed: null,
      child: RotationTransition(
        turns: new AlwaysStoppedAnimation(_clearDirection > 0
            ? _clearDirection / 360
            : (_clearDirection + 360) / 360),
        //if you want you can add animation effect for rotate
        child: Ink(
          decoration: const ShapeDecoration(
            color: Colors.lightBlue,
            shape: CircleBorder(),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_upward),
            color: Colors.white,
            onPressed: () {},
          ),
        ),
      ),
    );
  }

  Widget compassProvider() {
    switch (situationCompass) {
      case WidgetCompass.scanning:
        return scanningWidget();
      case WidgetCompass.directing:
        return directingWidget();
    }
    return directingWidget();
  }

  Widget distanceProvider() {
    switch (situationDistance) {
      case WidgetDistance.ready:
        return readyWidget();
      case WidgetDistance.navigating:
        return navigateWidget();
    }
    return navigateWidget();
  }

  void onARKitViewCreated(ARKitController arkitController) {
    this.arkitController = arkitController;
    this.arkitController.onAddNodeForAnchor = onAnchorWasFound;
  }

  void onAnchorWasFound(ARKitAnchor anchor) {
    if (anchor is ARKitImageAnchor) {
      //if you want to block AR while you aren't close to target > add "if (situationDistance==WidgetDistance.ready)" here
      setState(() => anchorWasFound = true);

      final materialCard = ARKitMaterial(
        lightingModelName: ARKitLightingModel.lambert,
        // diffuse: ARKitMaterialProperty(image: 'firatcard.png'),
      );

      final image =
          ARKitPlane(height: 0.4, width: 0.4, materials: [materialCard]);

      final targetPosition = anchor.transform.getColumn(3);
      final node = ARKitNode(
        geometry: image,
        position: vector.Vector3(
            targetPosition.x, targetPosition.y, targetPosition.z),
        eulerAngles: vector.Vector3.zero(),
      );
      arkitController.add(node);
    }
  }

// ARCORE
  void _onArCoreViewCreated(ArCoreController controller, Color clr) {
    arCoreController = controller;
    _addCylindre(arCoreController, clr);
    arCoreController.onNodeTap = (name) => onTapHandler(name);
    // arCoreController.onPlaneDetected = (plane) => showMsg(plane, "Plane mil gya ha.");
  }

  void showMsg(/*ArCorePlane plane,*/ String message) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        content: Text(message),
        actions: <Widget>[
          TextButton(
            child: const Text('Theek Hai!'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void onTapHandler(String name) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          AlertDialog(content: Text('onNodeTap on $name')),
    );
  }

  void _addCylindre(ArCoreController controller, Color clr) {
    final material = ArCoreMaterial(
      color: clr,
      reflectance: 1.0,
    );
    final cylindre = ArCoreCylinder(
      materials: [material],
      radius: 0.5,
      height: 0.3,
    );
    final node = ArCoreNode(
        shape: cylindre,
        position: vector.Vector3(0.0, -0.5, -2.0),
        name: "A Cylinder");
    controller.addArCoreNode(node);
  }
}
