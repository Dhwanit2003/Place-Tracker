import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../transitions/SlideTransition.dart';
import 'MapPage.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {

  PageController _pageController = PageController();
  int _currentIndex = 0;


  Map<String, List<MarkerData>> _markersByCategory = {
    'Favorites': [],
    'Visited': [],
    'Want to go': []
  };

  static const Map<String, IconData> iconMap = {
    "favorite": Icons.favorite,
    "check_circle": Icons.check_circle,
    "location_on": Icons.location_on,
    "star": Icons.star,
    "default": Icons.location_pin, // Fallback
  };


  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchMarkersFromFirebase(); // Fetch marker data from Firebase when the page loads
  }

  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMarkersFromFirebase() async {
    String deviceId = await getDeviceId();
    final docSnapshot = await FirebaseFirestore.instance.collection('Devices').doc(deviceId).get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data();
      if (data != null && data.containsKey('Markers')) {
        final markersMap = data['Markers'];

        for (var category in ['favorites', 'visited', 'want to go']) {
          if (markersMap.containsKey(category.toLowerCase())) {
            _markersByCategory[category] = (markersMap[category.toLowerCase()] as List)
                .map((markerData) => MarkerData(
              position: LatLng(markerData['latitude'], markerData['longitude']),
              iconData: iconMap[markerData['iconData']] ?? Icons.error, // 🔥 FIXED
              color: Color(markerData['color']),
            ))
                .toList();
          }
        }
      }
    }
    setState(() {}); // Update UI
  }


  Future<bool> signOutFromGoogle() async {

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();

      return true;

    }
    on Exception catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                context.go('/map', extra: SlideDirection.backward);
              },
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 20),
            const Text('Dashboard', style: TextStyle(color: Colors.white),),

            Padding(
              padding: const EdgeInsets.only(left: 170.0),
              child: GestureDetector(
                  onTap: () async {
                    bool signOutSuccess = await signOutFromGoogle();
                    if(signOutSuccess){
                      context.go ('/');
                    }
                    else{
                      print('Error during sign out');
                    }
                  },
                  child: const Icon(Icons.power_settings_new)
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Section Titles
          Container(
            padding: const EdgeInsets.all(25),
            color: Colors.grey[200],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionTitle("Favorites", 0),
                _buildSectionTitle("Visited", 1),
                _buildSectionTitle("Want to go", 2),
              ],
            ),
          ),
          // Sliding Content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              children: [
                _buildSectionContent("Favorites", Icons.favorite, Colors.red),
                _buildSectionContent(
                    "Visited", Icons.check_circle, Colors.green),
                _buildSectionContent(
                    "Want to go", Icons.location_on, Colors.blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, int index) {
    bool isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () {
        _pageController.jumpToPage(index);
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.green : Colors.black,
            ),
          ),
          const SizedBox(height: 5,),
          if(isActive)
            Container(
              width: 50,
              height: 3,
              color: Colors.green,
            ),
        ],
      ),

    );
  }

  Widget _buildSectionContent(String title, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 60),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          if (_markersByCategory[title]?.isNotEmpty ?? false)
            Expanded(
              child: ListView.builder(
                itemCount: _markersByCategory[title]?.length ?? 0,
                itemBuilder: (context, index) {
                  final marker = _markersByCategory[title]![index];
                  return ListTile(
                    leading: Icon(marker.iconData, color: marker.color),
                    title: Text("Marker at ${marker.position.latitude}, ${marker.position.longitude}"),
                  );
                },
              ),
            )
          else
            const Text("No markers in this category."),
        ],
      ),
    );
  }
}


