import 'dart:math';
import 'package:ambulance_service/View/HomePage/detailpage.dart';
import 'package:ambulance_service/View/LocationScreen/locationscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _drivers = [];
  GeoPoint? _userLocation;

  @override
  void initState() {
    super.initState();
    _getCurrentUserLocation();
  }

  // Get current user's location from Firestore
  Future<void> _getCurrentUserLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user ID
      String? userId = _auth.currentUser?.uid;
      
      if (userId != null) {
        // Get user location from 'user_locations' collection
        DocumentSnapshot userLocationDoc = await _firestore
            .collection('user_locations')
            .doc(userId)
            .get();
            
        if (userLocationDoc.exists) {
          Map<String, dynamic> data = userLocationDoc.data() as Map<String, dynamic>;
          setState(() {
            _userLocation = GeoPoint(
              data['latitude'] as double, 
              data['longitude'] as double
            );
          });
        } else {
          // If no stored location, request current device location
          await _requestCurrentLocation();
        }
      } else {
        // If no logged in user, request current device location
        await _requestCurrentLocation();
      }
      
      // After getting user location, fetch drivers
     // After getting user location, fetch drivers
      await _fetchDrivers();
      
    } catch (e) {
      print('Error getting user location: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Request current device location
  Future<void> _requestCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.whileInUse || 
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          _userLocation = GeoPoint(position.latitude, position.longitude);
        });
        
        // Update user location in Firestore
        await _updateUserLocationInFirestore(position.latitude, position.longitude);
      }
    } catch (e) {
      print('Error getting device location: $e');
    }
  }
  
  // Update user location in Firestore
  Future<void> _updateUserLocationInFirestore(double latitude, double longitude) async {
    try {
      String? userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _firestore.collection('user_locations').doc(userId).set({
          'latitude': latitude,
          'longitude': longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Error updating user location in Firestore: $e');
    }
  }
  
  // Calculate distance between two GeoPoints using Haversine formula
  double _calculateDistance(GeoPoint start, GeoPoint end) {
    const double earthRadius = 6371.0; // Earth radius in kilometers
    
    // Convert to radians
    final double startLat = start.latitude * pi / 180;
    final double endLat = end.latitude * pi / 180;
    final double latDiff = (end.latitude - start.latitude) * pi / 180;
    final double lngDiff = (end.longitude - start.longitude) * pi / 180;
    
    final double a = sin(latDiff / 2) * sin(latDiff / 2) +
                    cos(startLat) * cos(endLat) *
                    sin(lngDiff / 2) * sin(lngDiff / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Distance in kilometers
  }
  
  // Fetch all drivers and sort by distance
  Future<void> _fetchDrivers() async {
    if (_userLocation == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    try {
      // Step 1: Get all drivers
      QuerySnapshot driversSnapshot = await _firestore
          .collection('drivers')
          .get();
      
      List<Map<String, dynamic>> driversWithDistance = [];
      
      // Step 2: For each driver, get their location and calculate distance
      for (var doc in driversSnapshot.docs) {
        Map<String, dynamic> driverData = doc.data() as Map<String, dynamic>;
        String driverId = driverData['uid'] ?? doc.id;
        
        // Get driver location
        DocumentSnapshot driverLocationDoc = await _firestore
            .collection('driver_locations')
            .doc(driverId)
            .get();
            
        if (driverLocationDoc.exists) {
          Map<String, dynamic> locationData = driverLocationDoc.data() as Map<String, dynamic>;
          
          // Create GeoPoint from location data
          GeoPoint driverLocation = GeoPoint(
            locationData['latitude'] as double,
            locationData['longitude'] as double
          );
          
          // Calculate distance
          double distance = _calculateDistance(_userLocation!, driverLocation);
          
          // Add driver with distance to list
          driversWithDistance.add({
            ...driverData,
            'id': doc.id,
            'distance': distance,
            'location': driverLocation,
          });
        }
      }
      
      // Step 3: Sort drivers by distance
      driversWithDistance.sort((a, b) => 
        (a['distance'] as double).compareTo(b['distance'] as double)
      );
      
      setState(() {
        _drivers = driversWithDistance;
        _isLoading = false;
      });
      
    } catch (e) {
      print('Error fetching drivers: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Filter drivers by search query
  List<Map<String, dynamic>> _getFilteredDrivers() {
    if (searchQuery.isEmpty) {
      return _drivers;
    }
    
    return _drivers.where((driver) {
      final name = (driver['name'] ?? '').toString().toLowerCase();
      final phone = (driver['phone'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase()) || 
             phone.contains(searchQuery.toLowerCase());
    }).toList();
  }
  
  void _showLocationSelectionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationSelectionScreen(
          onLocationSelected: (double latitude, double longitude, String address) async {
            // Update user location in state
            setState(() {
              _userLocation = GeoPoint(latitude, longitude);
              _isLoading = true;
            });
            
            // Update user location in Firestore
            await _updateUserLocationInFirestore(latitude, longitude);
            
            // Refetch drivers with new location
            await _fetchDrivers();
            
            // Show confirmation
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Location updated to: $address'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }
  
  // Make a phone call
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    
    try {
      await launchUrl(launchUri);
    } catch (e) {
      print('Could not launch phone call: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not launch phone call'),
        ),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredDrivers = _getFilteredDrivers();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'App Name',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
              },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                fillColor: Colors.grey.shade700,
                filled: true,
                hintText: 'Search...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Near by Ambulance...',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              )
            : filteredDrivers.isEmpty
              ? Center(
                  child: Text(
                    searchQuery.isEmpty 
                      ? 'No drivers available'
                      : 'No drivers match your search',
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = filteredDrivers[index];
                    final name = driver['name'] ?? 'Unknown';
                    final phone = driver['phone'] ?? 'No phone';
                    final distance = driver['distance'] as double;
                    final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.shade300,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: ListTile(
                          onTap: () {
                            // Navigate to driver detail screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DriverDetailScreen(driver: driver),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade700,
                            child: Text(
                              firstLetter,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                phone,
                                style: const TextStyle(color: Colors.black87),
                              ),
                              Text(
                                '${distance.toStringAsFixed(1)} km away',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.phone, color: Colors.black),
                            onPressed: () => _makePhoneCall(phone),
                          ),
                          isThreeLine: true,
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: const Icon(Icons.location_on),
        onPressed: _showLocationSelectionScreen,
      ),
    );
  }
}