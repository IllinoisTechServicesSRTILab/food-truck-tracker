import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as lc;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:typed_data';

import '../models/truck_model.dart';
import '../utils/Utils.dart';
import '../secret.dart';
import '../services/user_location_service.dart';

const double CAMERA_ZOOM = 13;
const double CAMERA_TILT = 0;
const double CAMERA_BEARING = 30;

class MapDirectionViewArguments {
	//Location curLocation;
	Location targetLocation;
	MapDirectionViewArguments({this.targetLocation});
}

class MapDirectionView extends StatefulWidget {
	static String id = "truck_direction";

	//Location curLocation;
	Location targetLocation;

	//MapDirectionView({this.curLocation, this.targetLocation});
  	MapDirectionView({this.targetLocation});

	@override
	State<StatefulWidget> createState() => MapDirectionState();
}

class MapDirectionState extends State<MapDirectionView> {

	StreamSubscription _locationSubscription;
	lc.LocationData _currentLocation;
	lc.Location _locationTracker;

	Completer<GoogleMapController> _controller = Completer();
	// this set will hold my markers
	Set<Marker> _markers = {};
	// this will hold the generated polylines
	Set<Polyline> _polylines = {};
	// this will hold each polyline coordinate as Lat and Lng pairs
	List<LatLng> polylineCoordinates = [];
	// generates every polyline between start and finish
	PolylinePoints polylinePoints = PolylinePoints(); 

	BitmapDescriptor sourceIcon;
	BitmapDescriptor destinationIcon;
	LatLng _sourceLocation;
	LatLng _destLocation;
	bool _isLocationLoaded;
	@override 
	void initState() {
		super.initState();
		//initialize current location
		_destLocation = LatLng(widget.targetLocation.lat,  widget.targetLocation.lng);
		_locationTracker = new lc.Location();
	 	_isLocationLoaded = false;
		_locationTracker.onLocationChanged.listen((lc.LocationData cLoc) {
				_isLocationLoaded = true;
				_currentLocation = cLoc;
				lastLocation = cLoc;
				updatePinOnMap();
		});

    	_setSourceAndDestinationIcons();
		setInitialLocation();
	}

	void setInitialLocation() async {
		// set the initial location by pulling the user's
		// current location from the location's getLocation()
		_currentLocation = await _locationTracker.getLocation().timeout(Duration(seconds: 1), onTimeout: () => lastLocation);
		lastLocation = _currentLocation;
		this.setState(() {
			_isLocationLoaded = true;
		});
	}

  void updatePinOnMap() async {
    CameraPosition cPosition = CameraPosition(
      zoom: CAMERA_ZOOM,
      tilt: CAMERA_TILT,
      bearing: CAMERA_BEARING,
      target: LatLng(_currentLocation.latitude,
					_currentLocation.longitude),
    );
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(cPosition));
    setState(() {
      // updated position
      var pinPosition = LatLng(_currentLocation.latitude,
					_currentLocation.longitude);

      // the trick is to remove the marker (by id)
      // and add it again at the updated location
      _markers.removeWhere(
              (m) => m.markerId.value == 'sourcePin');
      _markers.add(Marker(
          markerId: MarkerId('sourcePin'),
          position: pinPosition, // updated position
          icon: sourceIcon
      ));
      // setPolylines(); 
    });
    
  }


  void _setSourceAndDestinationIcons() async {
		AssetUtils.getBytesFromAsset('images/current-location.png', 50)
	      			.then((bytes) {
	      					sourceIcon = BitmapDescriptor.fromBytes(bytes);
	      				});
		AssetUtils.getBytesFromAsset('images/marker.png', 100)
					.then((bytes) {
							destinationIcon = BitmapDescriptor.fromBytes(bytes);
						});
	}

	void _onMapCreated(GoogleMapController controller) {
	   _controller.complete(controller);
	   setMapPins();
	   //setPolylines();
	}

	void setMapPins() {
		if (_currentLocation == null) return;

		// source pin
		var pinPosition = LatLng(_currentLocation.latitude,
				_currentLocation.longitude);
		//_destLocation = LatLng(widget.targetLocation.lat,  widget.targetLocation.lng);

			_markers.add(Marker(
				markerId: MarkerId('sourcePin'),
				position: pinPosition,
				icon: sourceIcon
			));
			// destination pin
			_markers.add(Marker(
				markerId: MarkerId('destPin'),
				position: _destLocation ,
				icon: destinationIcon
			));
		setPolylines();
	}

	void setPolylines() async {
    	_polylines.clear();
		polylineCoordinates.clear(); 
		await
		  polylinePoints?.getRouteBetweenCoordinates(
					GOOGLE_MAP_API_KEY,
					_currentLocation.latitude,
					_currentLocation.longitude,
				    _destLocation.latitude,
				    _destLocation.longitude)
		  .then((result) {
				if(result.isNotEmpty){
				  // loop through all PointLatLng points and convert them
				  // to a list of LatLng, required by the Polyline
				  result.forEach((PointLatLng point){
				  	print("added ${point.latitude}, ${point.longitude}" );
				     polylineCoordinates.add(
				        LatLng(point.latitude, point.longitude));
				  });
				}
		  	});
		  		
		setState(() {
		  // create a Polyline instance
		  // with an id, an RGB color and the list of LatLng pairs
		  Polyline polyline = Polyline(
		     polylineId: PolylineId("poly"),
		     color: Color.fromARGB(255, 40, 122, 198),
		     points: polylineCoordinates
		  );

		  // add the constructed polyline as a set of points
		  // to the polyline set, which will eventually
		  // end up showing up on the map
		  _polylines.add(polyline);
		});
	}

	@override
	Widget build(BuildContext context) {
		if (!_isLocationLoaded) {
			return Container(
		    child: Align(
		      alignment: Alignment.center,
		      child: CircularProgressIndicator(),
		    ),
		  );
		}
		LatLng gcenter = LatLng(widget.targetLocation.lat, widget.targetLocation.lng);
		_destLocation = LatLng(widget.targetLocation.lat,  widget.targetLocation.lng);
	   CameraPosition initialLocation = CameraPosition(
	      zoom: CAMERA_ZOOM,
	      bearing: CAMERA_BEARING,
	      tilt: CAMERA_TILT,
	      target: gcenter
	   );
		if (_currentLocation != null) {
			initialLocation = CameraPosition(
					target: LatLng(_currentLocation.latitude,
							_currentLocation.longitude),
					zoom: CAMERA_ZOOM,
					tilt: CAMERA_TILT,
					bearing: CAMERA_BEARING
			);
		}
	   return GoogleMap(
	      //myLocationEnabled: true,
	      compassEnabled: true,
	      tiltGesturesEnabled: false,
	      markers: _markers,
	      polylines: _polylines,
	      mapType: MapType.normal,
	      initialCameraPosition: initialLocation,
	      onMapCreated: (GoogleMapController controller) {
					_controller.complete(controller);
					setMapPins();
				}
	   );
	}
}