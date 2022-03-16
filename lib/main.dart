import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gmaps/directions_model.dart';
import 'package:flutter_gmaps/directions_repository.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Google Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.white,
      ),
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(37.773972, -122.431297),
    zoom: 11.5,
  );

  GoogleMapController _googleMapController;
  Marker _origin;
  Marker _destination;
  Directions _info;
  TextEditingController place = TextEditingController();
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    permissions();
  }

  void permissions() async {
    await loc.Location().requestPermission();
  }

  @override
  void dispose() {
    _googleMapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomSheet: BottomSheet(
        builder: (context) {
          return Container(
            height: 200,
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.all(10),
                  child: TextFormField(
                    controller: place,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Start',
                        hintText: 'From',
                        suffixIcon: IconButton(
                            onPressed: () async {
                              setState(() {
                                _origin = null;
                                _destination = null;
                              });

                              Position position =
                                  await Geolocator.getCurrentPosition(
                                      desiredAccuracy: LocationAccuracy.best,
                                      timeLimit: const Duration(seconds: 10));
                              _addMarker(LatLng(
                                  position.latitude, position.longitude));
                              final GoogleMapController controller =
                                  await _controller.future;
                              controller.animateCamera(
                                  CameraUpdate.newCameraPosition(CameraPosition(
                                      target: LatLng(position.latitude,
                                          position.longitude),
                                      zoom: 8)));
                              List<Placemark> placemarks =
                                  await placemarkFromCoordinates(
                                position.latitude ?? 0,
                                position.longitude ?? 0,
                              );

                              place.text = placemarks
                                      .map((e) => e.name)
                                      .toList()
                                      .join(" , ") +
                                  " - ${placemarks.first.postalCode}";
                            },
                            icon: Icon(
                              Icons.gps_fixed,
                            ))),
                    onSaved: (value) {
                      setState(() {
                        _origin = null;
                      });

                      print(value);
                      updateLocation(value);
                    },
                  ),
                ),
                Container(
                  margin: EdgeInsets.all(10),
                  child: TextField(
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Destination',
                      // hintText: 'To',
                    ),
                    onSubmitted: (value) {
                      setState(() {
                        _destination = null;
                      });

                      print(value);
                      updateLocation(value);
                    },
                  ),
                ),
                if (_info != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6.0,
                      horizontal: 12.0,
                    ),
                    child: Text(
                      'Distance : ${_info.totalDistance}, Duration : ${_info.totalDuration}',
                      style: const TextStyle(
                        fontSize: 18.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        onClosing: () {
          Navigator.pop(context);
        },
      ),
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Google Maps'),
        actions: [
          if (_origin != null)
            TextButton(
              onPressed: () => _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _origin.position,
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                primary: Colors.green,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('ORIGIN'),
            ),
          if (_destination != null)
            TextButton(
              onPressed: () => _googleMapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: _destination.position,
                    zoom: 14.5,
                    tilt: 50.0,
                  ),
                ),
              ),
              style: TextButton.styleFrom(
                primary: Colors.blue,
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: const Text('DEST'),
            )
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            initialCameraPosition: _initialCameraPosition,
            markers: {
              if (_origin != null) _origin,
              if (_destination != null) _destination
            },
            polylines: {
              if (_info != null)
                Polyline(
                  polylineId: const PolylineId('overview_polyline'),
                  color: Colors.red,
                  width: 5,
                  points: _info.polylinePoints
                      .map((e) => LatLng(e.latitude, e.longitude))
                      .toList(),
                ),
            },
            onLongPress: _addMarker,
          ),
        ],
      ),
      /*   floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.black,
        onPressed: () => _googleMapController.animateCamera(
          _info != null
              ? CameraUpdate.newLatLngBounds(_info.bounds, 100.0)
              : CameraUpdate.newCameraPosition(_initialCameraPosition),
        ),
        child: const Icon(Icons.center_focus_strong),
      ), */
    );
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  void _addMarker(LatLng pos) async {
    if (_origin == null || (_origin != null && _destination != null)) {
      // Origin is not set OR Origin/Destination are both set
      // Set origin
      setState(() {
        _origin = Marker(
          markerId: const MarkerId('origin'),
          infoWindow: const InfoWindow(title: 'Origin'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          position: pos,
        );
        // Reset destination
        _destination = null;

        // Reset info
        _info = null;
      });
    } else {
      // Origin is already set
      // Set destination
      setState(() {
        _destination = Marker(
          markerId: const MarkerId('destination'),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          position: pos,
        );
      });

      // Get directions
      final directions = await DirectionsRepository()
          .getDirections(origin: _origin.position, destination: pos);
      setState(() => _info = directions);
    }
  }

  showDialog(context) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Wrap(
            children: [
              ListTile(
                leading: Icon(Icons.share),
                title: Text('Share'),
              ),
              ListTile(
                leading: Icon(Icons.copy),
                title: Text('Copy Link'),
              ),
              ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
              ),
            ],
          );
        });
  }

  final Completer<GoogleMapController> _controller = Completer();
  void updateLocation(String selectedLocation) async {
    final GoogleMapController controller = await _controller.future;
    List<Location> locations = await locationFromAddress(selectedLocation);
    _addMarker(LatLng(locations.first.latitude, locations.first.longitude));
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(locations.first.latitude, locations.first.longitude),
        zoom: 8)));
  }
}
