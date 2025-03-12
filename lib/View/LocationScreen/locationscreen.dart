// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:http/http.dart' as http;
// import 'dart:convert';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// class LocationSelectionScreen extends StatefulWidget {
//   final Function(double latitude, double longitude, String address) onLocationSelected;

//   const LocationSelectionScreen({
//     Key? key,
//     required this.onLocationSelected,
//   }) : super(key: key);

//   @override
//   State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
// }

// class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
//   final TextEditingController _searchController = TextEditingController();
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   bool _isSearching = false;
//   bool _isLoadingCurrentLocation = false;
//   bool _isLoadingFirestoreData = true;
//   List<Map<String, dynamic
//   >> _searchResults = [];
//   String _currentAddress = 'Unknown location';
//   LatLng _currentLocation = LatLng(0.0, 0.0);
//   LatLng? _selectedLocation;
//   List<Map<String, dynamic>> _driverLocations = [];

//   // Nominatim API URL
//   final String nominatimApiUrl = "https://nominatim.openstreetmap.org/search";

//   @override
//   void initState() {
//     super.initState();
//     _loadUserLocation();
//     _loadDriverLocations();
//   }

//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
//   }

//   // Load user location from Firestore
//   Future<void> _loadUserLocation() async {
//     setState(() {
//       _isLoadingFirestoreData = true;
//     });

//     try {
//       final userId = _auth.currentUser?.uid;
//       if (userId != null) {
//         DocumentSnapshot userLocationDoc = await _firestore
//             .collection('user_locations')
//             .doc(userId)
//             .get();

//         if (userLocationDoc.exists) {
//           Map<String, dynamic> data = userLocationDoc.data() as Map<String, dynamic>;
          
//           if (data.containsKey('latitude') && data.containsKey('longitude')) {
//             double latitude = data['latitude'];
//             double longitude = data['longitude'];
            
//             // Get address from coordinates
//             List<Placemark> placemarks = await placemarkFromCoordinates(
//               latitude,
//               longitude,
//             );

//             if (placemarks.isNotEmpty) {
//               Placemark place = placemarks.first;
//               String address = _formatAddress(place);

//               setState(() {
//                 _currentLocation = LatLng(latitude, longitude);
//                 _currentAddress = address.isNotEmpty ? address : 'Unknown location';
//               });
//             } else {
//               setState(() {
//                 _currentLocation = LatLng(latitude, longitude);
//                 _currentAddress = 'Location found, but address unknown';
//               });
//             }
//           } else {
//             // If user location doesn't have coordinates, get current device location
//             await _getCurrentLocation();
//           }
//         } else {
//           // If user location doesn't exist, get current device location
//           await _getCurrentLocation();
//         }
//       } else {
//         await _getCurrentLocation();
//       }
//     } catch (e) {
//       print('Error loading user location from Firestore: $e');
//       await _getCurrentLocation();
//     } finally {
//       setState(() {
//         _isLoadingFirestoreData = false;
//       });
//     }
//   }

//   // Load driver locations from Firestore
//   Future<void> _loadDriverLocations() async {
//     try {
//       QuerySnapshot driverLocationsSnapshot = await _firestore
//           .collection('driver_locations')
//           .get();

//       List<Map<String, dynamic>> drivers = [];
      
//       for (var doc in driverLocationsSnapshot.docs) {
//         Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
//         if (data.containsKey('latitude') && data.containsKey('longitude')) {
//           drivers.add({
//             'id': doc.id,
//             'latitude': data['latitude'],
//             'longitude': data['longitude'],
//           });
//         }
//       }

//       setState(() {
//         _driverLocations = drivers;
//       });
//     } catch (e) {
//       print('Error loading driver locations: $e');
//     }
//   }

//   // Format address from Placemark
//   String _formatAddress(Placemark place) {
//     String address = '';

//     if (place.street != null && place.street!.isNotEmpty) {
//       address += place.street!;
//     }

//     if (place.locality != null && place.locality!.isNotEmpty) {
//       address += address.isNotEmpty ? ', ${place.locality}' : place.locality!;
//     }

//     if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
//       address += address.isNotEmpty ? ', ${place.administrativeArea}' : place.administrativeArea!;
//     }

//     if (place.country != null && place.country!.isNotEmpty) {
//       address += address.isNotEmpty ? ', ${place.country}' : place.country!;
//     }

//     return address;
//   }

//   // Get current device location
//   Future<void> _getCurrentLocation() async {
//     setState(() {
//       _isLoadingCurrentLocation = true;
//     });

//     try {
//       LocationPermission permission = await Geolocator.checkPermission();
//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }

//       if (permission == LocationPermission.whileInUse ||
//           permission == LocationPermission.always) {
//         Position position = await Geolocator.getCurrentPosition();

//         // Get address from coordinates
//         List<Placemark> placemarks = await placemarkFromCoordinates(
//           position.latitude,
//           position.longitude,
//         );

//         if (placemarks.isNotEmpty) {
//           Placemark place = placemarks.first;
//           String address = _formatAddress(place);

//           setState(() {
//             _currentAddress = address.isNotEmpty ? address : 'Unknown location';
//             _currentLocation = LatLng(position.latitude, position.longitude);
//             _isLoadingCurrentLocation = false;
//           });
//         } else {
//           setState(() {
//             _currentAddress = 'Location found, but address unknown';
//             _currentLocation = LatLng(position.latitude, position.longitude);
//             _isLoadingCurrentLocation = false;
//           });
//         }
//       } else {
//         setState(() {
//           _currentAddress = 'Location permission denied';
//           _isLoadingCurrentLocation = false;
//         });
//       }
//     } catch (e) {
//       print('Error getting current location: $e');
//       setState(() {
//         _currentAddress = 'Error getting location';
//         _isLoadingCurrentLocation = false;
//       });
//     }
//   }

//   // Search for location using Nominatim API
//   Future<void> _searchLocation(String query) async {
//     if (query.trim().isEmpty) {
//       setState(() {
//         _searchResults = [];
//         _isSearching = false;
//       });
//       return;
//     }

//     setState(() {
//       _isSearching = true;
//     });

//     try {
//       final response = await http.get(
//         Uri.parse("$nominatimApiUrl?q=$query&format=json"),
//       );

//       if (response.statusCode == 200) {
//         List<dynamic> data = json.decode(response.body);
//         List<Map<String, dynamic>> results = [];

//         for (var item in data) {
//           results.add({
//             'address': item['display_name'],
//             'latitude': double.parse(item['lat']),
//             'longitude': double.parse(item['lon']),
//           });
//         }

//         setState(() {
//           _searchResults = results;
//           _isSearching = false;
//         });
//       } else {
//         throw Exception('Failed to load search results');
//       }
//     } catch (e) {
//       print('Error searching location: $e');
//       setState(() {
//         _searchResults = [];
//         _isSearching = false;
//       });
//     }
//   }

//   // Use current device location
//   void _useCurrentLocation() {
//     widget.onLocationSelected(
//       _currentLocation.latitude,
//       _currentLocation.longitude,
//       _currentAddress,
//     );
//     Navigator.pop(context);
//   }

//   // Select a location from search results
//   void _selectSearchResult(Map<String, dynamic> result) async {
//     final double latitude = result['latitude'];
//     final double longitude = result['longitude'];
//     final String address = result['address'];

//     setState(() {
//       _selectedLocation = LatLng(latitude, longitude);
//     });

//     // Update user location in Firestore
//     final userId = _auth.currentUser?.uid;
//     if (userId != null) {
//       await _firestore.collection('user_locations').doc(userId).set({
//         'latitude': latitude,
//         'longitude': longitude,
//         'updatedAt': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));
//     }

//     // Call the callback
//     widget.onLocationSelected(latitude, longitude, address);
//     Navigator.pop(context);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text(
//           'Choose location',
//           style: TextStyle(color: Colors.white),
//         ),
//         backgroundColor: Colors.black,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: Column(
//         children: [
//           // Choose current location button
//           InkWell(
//             onTap: (_isLoadingCurrentLocation || _isLoadingFirestoreData) ? null : _useCurrentLocation,
//             child: Container(
//               width: double.infinity,
//               padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
//               color: Colors.teal.shade200,
//               child: (_isLoadingCurrentLocation || _isLoadingFirestoreData)
//                   ? Row(
//                       children: [
//                         const Text(
//                           'Getting location data...',
//                           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                         ),
//                         const SizedBox(width: 10),
//                         SizedBox(
//                           width: 20,
//                           height: 20,
//                           child: CircularProgressIndicator(
//                             strokeWidth: 2,
//                             color: Colors.teal.shade800,
//                           ),
//                         ),
//                       ],
//                     )
//                   : Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         const Text(
//                           'Choose current location',
//                           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           _currentAddress,
//                           style: TextStyle(
//                             fontSize: 12,
//                             color: Colors.teal.shade800,
//                           ),
//                         ),
//                       ],
//                     ),
//             ),
//           ),

//           // Search location field
//           Container(
//             width: double.infinity,
//             padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
//             color: Colors.teal.shade100,
//             child: TextField(
//               controller: _searchController,
//               decoration: const InputDecoration(
//                 hintText: 'Search location',
//                 border: InputBorder.none,
//                 contentPadding: EdgeInsets.zero,
//               ),
//               onChanged: (value) {
//                 if (value.length > 2) {
//                   _searchLocation(value);
//                 } else if (value.isEmpty) {
//                   setState(() {
//                     _searchResults = [];
//                   });
//                 }
//               },
//             ),
//           ),

//           // Map and search results
//           Expanded(
//             child: Stack(
//               children: [
//                 // FlutterMap
//                 FlutterMap(
//                   options: MapOptions(
//                     center: _selectedLocation ?? _currentLocation,
//                     zoom: 14.0,
//                   ),
//                   children: [
//                     TileLayer(
//                       urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
//                       subdomains: ['a', 'b', 'c'],
//                     ),
//                     MarkerLayer(
//                       markers: [
//                         // User location marker
//                         Marker(
//                           point: _currentLocation,
//                           builder: (ctx) => const Icon(
//                             Icons.person_pin_circle,
//                             color: Colors.blue,
//                             size: 40,
//                           ),
//                         ),
                        
//                         // Selected location marker (if different from current)
//                         if (_selectedLocation != null)
//                           Marker(
//                             point: _selectedLocation!,
//                             builder: (ctx) => const Icon(
//                               Icons.location_pin,
//                               color: Colors.red,
//                               size: 40,
//                             ),
//                           ),
                        
//                         // Driver location markers
//                         ..._driverLocations.map((driver) => Marker(
//                           point: LatLng(driver['latitude'], driver['longitude']),
//                           builder: (ctx) => const Icon(
//                             Icons.local_taxi,
//                             color: Colors.green,
//                             size: 30,
//                           ),
//                         )).toList(),
//                       ],
//                     ),
//                   ],
//                 ),

//                 // Loading indicator for search
//                 if (_isSearching)
//                   const Center(
//                     child: CircularProgressIndicator(),
//                   ),

//                 // Search results
//                 if (_searchResults.isNotEmpty)
//                   Positioned(
//                     top: 0,
//                     left: 0,
//                     right: 0,
//                     child: Container(
//                       color: Colors.white,
//                       child: ListView.builder(
//                         shrinkWrap: true,
//                         itemCount: _searchResults.length,
//                         itemBuilder: (context, index) {
//                           final result = _searchResults[index];
//                           return ListTile(
//                             title: Text(result['address']),
//                             onTap: () => _selectSearchResult(result),
//                           );
//                         },
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LocationSelectionScreen extends StatefulWidget {
  final Function(double latitude, double longitude, String address) onLocationSelected;

  const LocationSelectionScreen({
    Key? key,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<LocationSelectionScreen> createState() => _LocationSelectionScreenState();
}

class _LocationSelectionScreenState extends State<LocationSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSearching = false;
  bool _isLoadingCurrentLocation = false;
  bool _isLoadingFirestoreData = true;
  List<Map<String, dynamic>> _searchResults = [];
  String _currentAddress = 'Unknown location';
  LatLng _defaultLocation = LatLng(37.4219999, -122.0840575); // Default to a reasonable location (Silicon Valley)
  LatLng _currentLocation = LatLng(37.4219999, -122.0840575); // Start with default location
  LatLng? _selectedLocation;
  List<Map<String, dynamic>> _driverLocations = [];
  MapController _mapController = MapController();
  bool _mapReady = false;

  // Nominatim API URL
  final String nominatimApiUrl = "https://nominatim.openstreetmap.org/search";

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _loadDriverLocations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load user location from Firestore
  Future<void> _loadUserLocation() async {
    setState(() {
      _isLoadingFirestoreData = true;
    });

    try {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        DocumentSnapshot userLocationDoc = await _firestore
            .collection('user_locations')
            .doc(userId)
            .get();

        if (userLocationDoc.exists) {
          Map<String, dynamic> data = userLocationDoc.data() as Map<String, dynamic>;
          
          if (data.containsKey('latitude') && data.containsKey('longitude')) {
            double latitude = data['latitude'];
            double longitude = data['longitude'];
            
            // Get address from coordinates
            List<Placemark> placemarks = await placemarkFromCoordinates(
              latitude,
              longitude,
            );

            if (placemarks.isNotEmpty) {
              Placemark place = placemarks.first;
              String address = _formatAddress(place);

              setState(() {
                _currentLocation = LatLng(latitude, longitude);
                _currentAddress = address.isNotEmpty ? address : 'Unknown location';
                _updateMapCenter();
              });
            } else {
              setState(() {
                _currentLocation = LatLng(latitude, longitude);
                _currentAddress = 'Location found, but address unknown';
                _updateMapCenter();
              });
            }
          } else {
            // If user location doesn't have coordinates, get current device location
            await _getCurrentLocation();
          }
        } else {
          // If user location doesn't exist, get current device location
          await _getCurrentLocation();
        }
      } else {
        await _getCurrentLocation();
      }
    } catch (e) {
      print('Error loading user location from Firestore: $e');
      await _getCurrentLocation();
    } finally {
      setState(() {
        _isLoadingFirestoreData = false;
      });
    }
  }

  // Helper method to update map center once coordinates are available
  void _updateMapCenter() {
    if (_mapReady && _mapController != null) {
      _mapController.move(_currentLocation, 14.0);
    }
  }

  // Load driver locations from Firestore
  Future<void> _loadDriverLocations() async {
    try {
      QuerySnapshot driverLocationsSnapshot = await _firestore
          .collection('driver_locations')
          .get();

      List<Map<String, dynamic>> drivers = [];
      
      for (var doc in driverLocationsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        if (data.containsKey('latitude') && data.containsKey('longitude')) {
          drivers.add({
            'id': doc.id,
            'latitude': data['latitude'],
            'longitude': data['longitude'],
          });
        }
      }

      setState(() {
        _driverLocations = drivers;
      });
    } catch (e) {
      print('Error loading driver locations: $e');
    }
  }

  // Format address from Placemark
  String _formatAddress(Placemark place) {
    String address = '';

    if (place.street != null && place.street!.isNotEmpty) {
      address += place.street!;
    }

    if (place.locality != null && place.locality!.isNotEmpty) {
      address += address.isNotEmpty ? ', ${place.locality}' : place.locality!;
    }

    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
      address += address.isNotEmpty ? ', ${place.administrativeArea}' : place.administrativeArea!;
    }

    if (place.country != null && place.country!.isNotEmpty) {
      address += address.isNotEmpty ? ', ${place.country}' : place.country!;
    }

    return address;
  }

  // Get current device location
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingCurrentLocation = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition();

        // Get address from coordinates
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          String address = _formatAddress(place);

          setState(() {
            _currentAddress = address.isNotEmpty ? address : 'Unknown location';
            _currentLocation = LatLng(position.latitude, position.longitude);
            _isLoadingCurrentLocation = false;
            _updateMapCenter();
          });
        } else {
          setState(() {
            _currentAddress = 'Location found, but address unknown';
            _currentLocation = LatLng(position.latitude, position.longitude);
            _isLoadingCurrentLocation = false;
            _updateMapCenter();
          });
        }
      } else {
        setState(() {
          _currentAddress = 'Location permission denied';
          _isLoadingCurrentLocation = false;
        });
      }
    } catch (e) {
      print('Error getting current location: $e');
      setState(() {
        _currentAddress = 'Error getting location';
        _isLoadingCurrentLocation = false;
      });
    }
  }

  // Search for location using Nominatim API
  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await http.get(
        Uri.parse("$nominatimApiUrl?q=$query&format=json"),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        List<Map<String, dynamic>> results = [];

        for (var item in data) {
          results.add({
            'address': item['display_name'],
            'latitude': double.parse(item['lat']),
            'longitude': double.parse(item['lon']),
          });
        }

        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      } else {
        throw Exception('Failed to load search results');
      }
    } catch (e) {
      print('Error searching location: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  // Use current device location
  void _useCurrentLocation() {
    widget.onLocationSelected(
      _currentLocation.latitude,
      _currentLocation.longitude,
      _currentAddress,
    );
    Navigator.pop(context);
  }

  // Select a location from search results
  void _selectSearchResult(Map<String, dynamic> result) async {
    final double latitude = result['latitude'];
    final double longitude = result['longitude'];
    final String address = result['address'];

    setState(() {
      _selectedLocation = LatLng(latitude, longitude);
      _mapController.move(_selectedLocation!, 14.0);
    });

    // Update user location in Firestore
    final userId = _auth.currentUser?.uid;
    if (userId != null) {
      await _firestore.collection('user_locations').doc(userId).set({
        'latitude': latitude,
        'longitude': longitude,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    // Call the callback
    widget.onLocationSelected(latitude, longitude, address);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Choose location',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Choose current location button
          InkWell(
            onTap: (_isLoadingCurrentLocation || _isLoadingFirestoreData) ? null : _useCurrentLocation,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
              color: Colors.teal.shade200,
              child: (_isLoadingCurrentLocation || _isLoadingFirestoreData)
                  ? Row(
                      children: [
                        const Text(
                          'Getting location data...',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose current location',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentAddress,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal.shade800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          // Search location field
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20.0),
            color: Colors.teal.shade100,
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search location',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                if (value.length > 2) {
                  _searchLocation(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _searchResults = [];
                  });
                }
              },
            ),
          ),

          // Map and search results
          Expanded(
            child: Stack(
              children: [
                // Loading indicator when data is still loading
                if (_isLoadingFirestoreData)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                
                // FlutterMap
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _currentLocation,
                    zoom: 14.0,
                    onMapReady: () {
                      setState(() {
                        _mapReady = true;
                        _updateMapCenter();
                      });
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        // User location marker
                        Marker(
                          point: _currentLocation,
                          builder: (ctx) => const Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                        
                        // Selected location marker (if different from current)
                        if (_selectedLocation != null)
                          Marker(
                            point: _selectedLocation!,
                            builder: (ctx) => const Icon(
                              Icons.location_pin,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        
                        // Driver location markers
                        ..._driverLocations.map((driver) => Marker(
                          point: LatLng(driver['latitude'], driver['longitude']),
                          builder: (ctx) => const Icon(
                            Icons.local_taxi,
                            color: Colors.green,
                            size: 30,
                          ),
                        )).toList(),
                      ],
                    ),
                  ],
                ),

                // Loading indicator for search
                if (_isSearching)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),

                // Search results
                if (_searchResults.isNotEmpty)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      color: Colors.white,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return ListTile(
                            title: Text(result['address']),
                            onTap: () => _selectSearchResult(result),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}