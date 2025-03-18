import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../icon_painter.dart';
import 'package:uuid/uuid.dart';
import '../map_style.dart';
import 'package:flutter/services.dart' show ByteData, Uint8List;


Future<String> getDeviceId() async {
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  String? deviceId = prefs.getString('device_id');

  if (deviceId == null) {
    deviceId = const Uuid().v4(); // Generate a new UUID
    await prefs.setString('device_id', deviceId); // Store it persistently
  }
  return deviceId;
}


class MapPage extends StatefulWidget {
  final String userName;
  final String userProfileImage;

  const MapPage({super.key,required this.userName,required this.userProfileImage});

  @override
  State<MapPage> createState() => _MapPageState();
}

class MarkerData {
  LatLng position;
  IconData iconData;
  final Color color;

  MarkerData({required this.position, required this.iconData,required this.color});
}


class _MapPageState extends State<MapPage> {
  late GoogleMapController mapController;
  LatLng _initialPosition = const LatLng(0.0, 0.0); // Default center position
  bool _isMapCreated = false;
  bool isNightVision = false;
  Set<String> pressedButtons = {};
  String deviceId = '';
  Timer? _locationUpdateTimer;
  Set<Marker> _markers = {};
  List<String> _profileNames = [];
  List<MarkerData> _markerPositions = [];


  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    fetchProfileNames().then((names){
      setState(() {
        _profileNames = names;
      });
    });
  }

  void _toggleMapStyle() {
    setState(() {
      isNightVision = !isNightVision;
      mapController?.setMapStyle(isNightVision ? nightVisionMapStyle : null);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    getDeviceId().then((id) {
      setState(() {
        deviceId = id;
      });
      _getCurrentLocation();
      _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _getCurrentLocation();
      });
      _fetchOtherDevicesLocations();
    });
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }




  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    if (mounted) {
      BitmapDescriptor customIcon = await _getMarkerIcon(widget.userProfileImage);

      setState(() {
        _initialPosition = LatLng(position.latitude, position.longitude);


        _markers.add(Marker(
          markerId: const MarkerId('currentLocation'),
          position: _initialPosition,
          infoWindow: InfoWindow(
            title: 'You are here',
            snippet: widget.userName, // Display user's name below the marker
          ),
          icon: customIcon,
        ));
      });

      if (_isMapCreated) {
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _initialPosition, zoom: 18.0),
          ),
        );
      }

      FirebaseFirestore.instance.collection('Devices').doc(widget.userName).set({
        'device_id' : deviceId,
        'latitude' : position.latitude,
        'longitude' : position.longitude,
        'timestamp' : Timestamp.now(),
        'username' : widget.userName,
        'profile_image' : widget.userProfileImage,
      }, SetOptions(merge: true)).then((value){
        print('Location updated');
      }
      ).catchError((error){
        print("Failed to update location: $error");
      });

    }
  }

  Future<void> _fetchOtherDevicesLocations() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return;
    }

    QuerySnapshot userSnapshot = await FirebaseFirestore.instance
        .collection('Devices')
        .where('username', isEqualTo: user.displayName)
        .get();
    if (userSnapshot.docs.isNotEmpty) {

      List<dynamic> friendList = userSnapshot.docs.first['Friends'] ?? [];

      if(friendList.isEmpty)
        return;

      FirebaseFirestore.instance
          .collection('Devices')
          .where('username' , whereIn: friendList)
          .snapshots()
          .listen((snapshot) async {
        Set<Marker> markers = {};

        for (var doc in snapshot.docs) {
          if (doc['device_id'] != deviceId) {
            double latitude = doc['latitude'];
            double longitude = doc['longitude'];
            String markedId = doc['device_id'];
            String userName = doc['username'];
            String profileImageUrl = doc['profile_image'];
            BitmapDescriptor customIcon = await _getMarkerIcon(profileImageUrl);

            markers.add(Marker(
              markerId: MarkerId(markedId),
              position: LatLng(latitude, longitude),
              infoWindow: InfoWindow(
                title: markedId,
                snippet: userName,
              ),
              icon: customIcon,
            ));
          }
        }

        setState(() {
          for (final newMarker in markers) {
            _markers.removeWhere((marker) =>
            marker.markerId == newMarker.markerId);
            _markers.add(newMarker);
          }
        });
      });
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(String imageUrl, {double scale = 1.2}) async {
    // Fetch the image from the URL
    final response = await http.get(Uri.parse(imageUrl));

    // Decode the image
    final imageCodec = await ui.instantiateImageCodec(response.bodyBytes);
    final frame = await imageCodec.getNextFrame();
    final image = frame.image;

    // Create a PictureRecorder and Canvas
    final pictureRecorder = ui.PictureRecorder();

    // Increase the canvas size based on the scale factor
    final canvasSize = Size(image.width * scale, image.height * scale);
    final canvas = Canvas(pictureRecorder, Rect.fromPoints(Offset(0, 0), Offset(canvasSize.width, canvasSize.height)));

    final paint = Paint();

    // Define the circle's radius based on the scaled size
    final radius = (canvasSize.width / 2.0);

    // Create a circular clipping path and draw the image on the canvas
    final rect = Rect.fromCircle(center: Offset(radius, radius), radius: radius);
    canvas.clipPath(Path()..addOval(rect));
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), rect, paint);

    // Convert the image to a PNG format
    final recordedImage = pictureRecorder.endRecording();
    final finalImage = await recordedImage.toImage(canvasSize.width.toInt(), canvasSize.height.toInt());

    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final bytes = byteData!.buffer.asUint8List();

    // Return the custom marker as a BitmapDescriptor
    return BitmapDescriptor.fromBytes(bytes);
  }


  void _requestPage(){
    if(mounted){
      context.go('/requests');
    }
  }

  void _gotoDashboard() {
    if (mounted) {
      context.go('/dashboard');
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    _isMapCreated = true;

    if (_initialPosition != const LatLng(0.0, 0.0)) {
      mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _initialPosition, zoom: 15.0),
        ),
      );
    }
  }

  void _toggleButton(String label) async {
    // Check if label is already pressed
    if (pressedButtons.contains(label)) {
      // If pressed, remove markers for that label
      _markers.removeWhere((marker) => marker.infoWindow.title == "$label Marker");
      pressedButtons.remove(label); // Remove label from pressed set
    } else {
      // Otherwise, add markers for that label
      final docSnapshot = await FirebaseFirestore.instance.collection('Devices').doc(deviceId).get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data();

        if (data != null && data.containsKey('Markers')) {
          final markersMap = data['Markers'];

          if (markersMap.containsKey(label.toLowerCase())) {
            for (var markerData in markersMap[label.toLowerCase()]) {
              final LatLng markerPosition = LatLng(markerData['latitude'], markerData['longitude']);
              final int iconCodePoint = markerData['iconData'];
              final int colorValue = markerData['color'];

              BitmapDescriptor markerIcon = await _getMarkerIconFromIconData(
                IconData(iconCodePoint, fontFamily: 'MaterialIcons'),
                Color(colorValue),
              );

              _markers.add(
                Marker(
                  markerId: MarkerId(markerPosition.toString()),
                  position: markerPosition,
                  icon: markerIcon,
                  infoWindow: InfoWindow(title: "$label Marker"),
                ),
              );
            }
          }
        }
      }

      pressedButtons.add(label); // Add label to pressed set
    }

    setState(() {}); // Trigger UI update
  }

  void _sendRequestToUser(String senderName, String recipientId) async {
    try {
      CollectionReference requests = FirebaseFirestore.instance.collection('Requests');

      // Query the Devices collection to get the sender's profile image
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Devices')
          .where('username', isEqualTo: senderName)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Extract the profile image URL from the first document
        String senderImageUrl = snapshot.docs.first['profile_image'] ?? '';

        // Add the request to the 'Requests' collection with the sender's image URL
        await requests.add({
          'SenderName': senderName,
          'recipientName': recipientId,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
          'sender_image': senderImageUrl,
        });

        print('Request sent successfully.');
      } else {
        print('Sender profile not found.');
      }
    } catch (e) {
      print('Error sending request: $e');
    }
  }

  Future<void> _showAlertDialog(String searchName, String deviceId) async{

    final recipientId = searchName;
    showDialog(
        context: context,
        builder: (BuildContext context)
        {
          return AlertDialog(
            title: const Text("Friend Request"),
            content: Text("Send Friend Request to $searchName "),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: (){
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('Yes'),
                onPressed: (){
                  _sendRequestToUser(deviceId,recipientId);
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        }
    );
  }

  Future<List<String>> fetchProfileNames() async{
    List<String> profileNames = [];
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('Devices').get();

    for(var doc in snapshot.docs){
      profileNames.add(doc['username']);
    }

    return profileNames;
  }



  void searchUser(String query) async{
    final usersCollection = FirebaseFirestore.instance.collection('Devices');

    QuerySnapshot querySnapshot = await usersCollection
        .where('username', isGreaterThanOrEqualTo : query)
        .where('username', isLessThanOrEqualTo: query + '\uf8ff')
        .get();
    setState(() {
      userList = querySnapshot.docs.map((doc) => doc['username'].toString())
          .where((username) => username != widget.userName)
          .toList();
    });
  }

  Color _getButtonColor(String buttonLabel) {
    return pressedButtons.contains(buttonLabel) ? Colors.green : Colors.purple[50]!;
  }

  Color _getTextColor(String buttonLabel) {
    return pressedButtons.contains(buttonLabel) ? Colors.white : Colors.black;
  }

  var userList = [];
  bool _isExpanded = false;


  void _toggleButtons() async {
    setState(() {
      _isExpanded = !_isExpanded;
    });

    if (_isExpanded) {
      // Clear any old markers
      _markers.clear();

      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _initialPosition, // Use the initial position as the marker position
          icon: BitmapDescriptor.defaultMarker, // Default marker icon
        ),
      );

      // Retrieve markers from Firebase
      await _loadMarkersFromFirebase();

      setState(() {}); // Trigger UI update after markers are loaded
    } else {
      // When collapsed, clear the markers and add a default marker
      setState(() {
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: _initialPosition,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      });
    }
  }

  Future<void> _loadMarkersFromFirebase() async {
    // Retrieve markers from Firebase
    final docSnapshot = await FirebaseFirestore.instance.collection('Devices').doc(deviceId).get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();

      if (data != null && data.containsKey('Markers')) {
        final markersMap = data['Markers'];

        // Loop through each category in the Markers map
        for (var category in ['favorites', 'visited', 'want to go']) {
          if (markersMap.containsKey(category)) {
            for (var markerData in markersMap[category]) {
              // Extract marker details
              final LatLng markerPosition = LatLng(markerData['latitude'], markerData['longitude']);
              final int iconCodePoint = markerData['iconData'];
              final int colorValue = markerData['color'];
              // Create icon with specified color
              BitmapDescriptor markerIcon = await _getMarkerIconFromIconData(IconData(iconCodePoint, fontFamily: 'MaterialIcons'), Color(colorValue));

              // Add marker to the map
              _markers.add(
                Marker(
                  markerId: MarkerId(markerPosition.toString()),
                  position: markerPosition,
                  icon: markerIcon,
                  infoWindow: InfoWindow(title: "$category Marker"),
                ),
              );
            }
          }
        }
      }
    }
    setState(() {}); // Trigger a UI update
  }


  void _onCameraMove(CameraPosition position) {
    // Clear the markers for the current frame

    if(_isExpanded){
      // Add the default marker at the current camera position
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'), // Unique ID for the default marker
          position: position.target, // Use the current camera position
          icon: BitmapDescriptor.defaultMarker, // Default marker icon
          infoWindow: InfoWindow(title: "Current Location"), // Optional info window
        ),
      );

      _addStoredMarkers();


      setState(() {});
    }
  }

  void _addStoredMarkers() async {

    for (MarkerData markerData in _markerPositions) {
      // Fetch the custom icon for the stored marker based on its icon data
      BitmapDescriptor markerIcon = await _getMarkerIconFromIconData(markerData.iconData,markerData.color);

      // Create and add the marker to the list
      _markers.add(
        Marker(
          markerId: MarkerId(markerData.position.toString()), // Use position for unique ID
          position: markerData.position, // Use the stored position
          icon: markerIcon, // Custom marker icon for stored markers
          infoWindow: InfoWindow(title: "Stored Marker"), // Optional info window
        ),
      );
    }

    setState(() {}); // Trigger UI update to display the markers
  }


  Future<BitmapDescriptor> _getMarkerIconFromIconData(IconData iconData,Color color) async{

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    const double size = 100.0;

    final icon = Icon(
      iconData,
      size: size,
      color: color, // Set the icon color as desired
    );

    final painter = IconPainter(icon);
    painter.paint(canvas,Size(size,size));

    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());

    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List bytes = byteData!.buffer.asUint8List();

    return BitmapDescriptor.fromBytes(bytes);

  }


  void _addMarker(IconData icon,Color color) async {

    final LatLngBounds bounds = await mapController.getVisibleRegion();

    LatLng markerPosition = LatLng(
      (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
      (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
    );

    BitmapDescriptor markerIcon = await _getMarkerIconFromIconData(icon,color);

    String category;
    if(icon == Icons.favorite){
      category = 'favorites';
    }
    else if(icon == Icons.flag){
      category = 'visited';
    }
    else if(icon == Icons.golf_course){
      category = 'want to go';
    }
    else{
      return;
    }

    _markerPositions.add(MarkerData(position: markerPosition, iconData: icon,color: color));


    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(DateTime.now().toString()),
          position: markerPosition,
          icon: markerIcon,
          infoWindow: InfoWindow(title: "Custom Icon Marker"),
        ),
      );
    });

    await FirebaseFirestore.instance.collection('Devices').doc(deviceId).set({
      'Markers':{
        category : FieldValue.arrayUnion([
          {
            'latitude': markerPosition.latitude,
            'longitude': markerPosition.longitude,
            'iconData': icon.codePoint,
            'color': color.value,
          }
        ]),
      }
    }, SetOptions(merge: true));

  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on_rounded,color: Colors.white,size: 25,),
                  SizedBox(width: 5,),
                  Text('Place Tracker App',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold,fontSize: 21),),
                ],
              ),
              Container(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap:_requestPage,
                        child: Icon(Icons.message,color: Colors.white,size: 22,),
                      ),
                      SizedBox(width: 10,),
                      GestureDetector(
                        onTap: _gotoDashboard,
                        child: const Icon(Icons.list_alt,color: Colors.white,size: 23,),
                      ),
                      IconButton(onPressed: _toggleMapStyle,
                        icon: Icon(isNightVision ? Icons.nights_stay : Icons.sunny,color: Colors.white,),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialPosition,
              zoom: 11.0,
            ),
            myLocationButtonEnabled: true,
            myLocationEnabled: false,
            markers: _markers,
            onCameraMove: _onCameraMove,
          ),
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              children: [
                SearchAnchor(
                    builder:(BuildContext context , SearchController controller){
                      return SearchBar(
                        controller: controller,
                        onTap: (){
                          controller.openView();
                        },
                        leading: const Icon(Icons.search),
                      );
                    },suggestionsBuilder: (BuildContext context , SearchController controller ) {
                  if(controller.text.isEmpty){
                    return [];
                  }
                  searchUser(controller.text);
                  return userList.map((searchName)=>ListTile(
                    title: Text(searchName),
                    onTap: (){
                      _showAlertDialog(searchName, widget.userName);
                    },
                  )
                  ).toList();

                  // List<String> filteredNames = _profileNames
                  //     .where((name) => name.toLowerCase().contains(controller.text.toLowerCase()))
                  //     .toList();
                  //
                  // return List<ListTile>.generate(filteredNames.length,(int index)   {
                  //   final String item = filteredNames[index];
                  //   String? recipientId = await getRecipientId(item);
                  //   return ListTile(
                  //     title: Text(item),
                  //     onTap: (){
                  //       setState(() {
                  //         _showAlertDialog(item,deviceId,recipientId);
                  //       });
                  //     },
                  //   );
                  // }
                }
                ),
                SizedBox(height: 10),
                // Space between SearchBar and Button
                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          onPressed: _toggleButtons,
                          style:ElevatedButton.styleFrom(backgroundColor:Colors.green),
                          child: Icon(Icons.location_on,
                            size: 25,color: Colors.white,
                          ),
                        ),
                      ),
                      if(_isExpanded) ... [
                        SizedBox( height: 10),
                        SizedBox(
                          height: 50,
                          width: 70,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                            onPressed: () {
                              _addMarker(Icons.favorite,Colors.red); // Add marker for favorite icon
                            },
                            child: Icon(Icons.favorite,
                              size: 25,color: Colors.red,
                            ),
                          ),
                        ),
                        SizedBox( height: 10),
                        SizedBox(
                          height: 50,
                          width: 70,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                            onPressed: (){
                              _addMarker(Icons.flag,Colors.blue);
                            },
                            child: Icon(Icons.flag,
                              size: 25,color: Colors.blue,
                            ),
                          ),
                        ),
                        SizedBox( height: 10),
                        SizedBox(
                          height: 50,
                          width: 70,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
                            onPressed: (){
                              _addMarker(Icons.golf_course,Colors.yellow);
                            },
                            child: Icon(Icons.golf_course,
                              size: 25,color: Colors.yellow,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Row(
              children: [
                _buildButton('Favorites'),
                _buildButton('Visited'),
                Expanded(child: _buildButton('Want to go')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Padding _buildButton(String label) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: ElevatedButton(
        onPressed: () {
          _toggleButton(label);
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(100, 50),
          backgroundColor: _getButtonColor(label),
        ),
        child: Text(
          label,
          style: TextStyle(color: _getTextColor(label)),
        ),
      ),
    );
  }


}
