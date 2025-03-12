import 'dart:math';

import 'package:ambulance_service/View/LocationScreen/locationscreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

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
                            onPressed: () {
                              // Implement call functionality
                            },
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
//   bool _isSearching = false;
//   bool _isLoadingCurrentLocation = false;
//   List<Map<String, dynamic>> _searchResults = [];
//   String _currentAddress = 'Unknown location';
//   double _currentLatitude = 0.0;
//   double _currentLongitude = 0.0;
  
//   @override
//   void initState() {
//     super.initState();
//     _getCurrentLocation();
//   }
  
//   @override
//   void dispose() {
//     _searchController.dispose();
//     super.dispose();
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
//           position.longitude
//         );
        
//         if (placemarks.isNotEmpty) {
//           Placemark place = placemarks.first;
//           String address = '';
          
//           if (place.street != null && place.street!.isNotEmpty) {
//             address += place.street!;
//           }
          
//           if (place.locality != null && place.locality!.isNotEmpty) {
//             address += address.isNotEmpty ? ', ${place.locality}' : place.locality!;
//           }
          
//           if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
//             address += address.isNotEmpty ? ', ${place.administrativeArea}' : place.administrativeArea!;
//           }
          
//           if (place.country != null && place.country!.isNotEmpty) {
//             address += address.isNotEmpty ? ', ${place.country}' : place.country!;
//           }
          
//           setState(() {
//             _currentAddress = address.isNotEmpty ? address : 'Unknown location';
//             _currentLatitude = position.latitude;
//             _currentLongitude = position.longitude;
//             _isLoadingCurrentLocation = false;
//           });
//         } else {
//           setState(() {
//             _currentAddress = 'Location found, but address unknown';
//             _currentLatitude = position.latitude;
//             _currentLongitude = position.longitude;
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
  
//   // Search for location by query
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
//       List<Location> locations = await locationFromAddress(query);
//       List<Map<String, dynamic>> results = [];
      
//       for (var location in locations) {
//         try {
//           List<Placemark> placemarks = await placemarkFromCoordinates(
//             location.latitude,
//             location.longitude,
//           );
          
//           if (placemarks.isNotEmpty) {
//             Placemark place = placemarks.first;
//             String address = '';
            
//             if (place.street != null && place.street!.isNotEmpty) {
//               address += place.street!;
//             }
            
//             if (place.locality != null && place.locality!.isNotEmpty) {
//               address += address.isNotEmpty ? ', ${place.locality}' : place.locality!;
//             }
            
//             if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) {
//               address += address.isNotEmpty ? ', ${place.administrativeArea}' : place.administrativeArea!;
//             }
            
//             if (place.country != null && place.country!.isNotEmpty) {
//               address += address.isNotEmpty ? ', ${place.country}' : place.country!;
//             }
            
//             results.add({
//               'address': address,
//               'latitude': location.latitude,
//               'longitude': location.longitude,
//             });
//           }
//         } catch (e) {
//           print('Error getting placemark: $e');
//         }
//       }
      
//       setState(() {
//         _searchResults = results;
//         _isSearching = false;
//       });
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
//       _currentLatitude,
//       _currentLongitude,
//       _currentAddress
//     );
//     Navigator.pop(context);
//   }
  
//   // Select a location from search results
//   void _selectSearchResult(Map<String, dynamic> result) {
//     widget.onLocationSelected(
//       result['latitude'],
//       result['longitude'],
//       result['address']
//     );
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
//             onTap: _isLoadingCurrentLocation ? null : _useCurrentLocation,
//             child: Container(
//               width: double.infinity,
//               padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
//               color: Colors.teal.shade200,
//               child: _isLoadingCurrentLocation
//                 ? Row(
//                     children: [
//                       const Text(
//                         'Getting current location...',
//                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                       ),
//                       const SizedBox(width: 10),
//                       SizedBox(
//                         width: 20,
//                         height: 20,
//                         child: CircularProgressIndicator(
//                           strokeWidth: 2,
//                           color: Colors.teal.shade800,
//                         ),
//                       ),
//                     ],
//                   )
//                 : Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       const Text(
//                         'Choose current location',
//                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         _currentAddress,
//                         style: TextStyle(
//                           fontSize: 12,
//                           color: Colors.teal.shade800,
//                         ),
//                       ),
//                     ],
//                   ),
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
//                 if (value.length > 2) { // Start search after typing at least 3 characters
//                   _searchLocation(value);
//                 } else if (value.isEmpty) {
//                   setState(() {
//                     _searchResults = [];
//                   });
//                 }
//               },
//             ),
//           ),
          
//           // Search results or placeholder map
//           Expanded(
//             child: _isSearching
//               ? const Center(
//                   child: CircularProgressIndicator(),
//                 )
//               : _searchResults.isNotEmpty
//                 ? ListView.builder(
//                     itemCount: _searchResults.length,
//                     itemBuilder: (context, index) {
//                       final result = _searchResults[index];
//                       return ListTile(
//                         title: Text(result['address']),
//                         onTap: () => _selectSearchResult(result),
//                       );
//                     },
//                   )
//                 : Stack(
//                     children: [
//                       // Simple placeholder map image
//                       Image.asset(
//                         'assets/map_placeholder.png', // Replace with your placeholder image
//                         width: double.infinity,
//                         height: double.infinity,
//                         fit: BoxFit.cover,
//                         errorBuilder: (context, error, stackTrace) {
//                           // Fallback if image not found
//                           return Container(
//                             width: double.infinity,
//                             height: double.infinity,
//                             color: Colors.grey.shade200,
//                             child: Center(
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 children: [
//                                   Icon(
//                                     Icons.map,
//                                     size: 80,
//                                     color: Colors.grey.shade400,
//                                   ),
//                                   const SizedBox(height: 16),
//                                   Text(
//                                     'Map View',
//                                     style: TextStyle(
//                                       fontSize: 16,
//                                       color: Colors.grey.shade600,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     'Search for a location or use current location',
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       color: Colors.grey.shade500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
                      
//                       // Static location markers
//                       Positioned(
//                         bottom: 16,
//                         right: 16,
//                         child: FloatingActionButton(
//                           backgroundColor: Colors.teal,
//                           mini: true,
//                           child: const Icon(Icons.my_location),
//                           onPressed: _getCurrentLocation,
//                         ),
//                       ),
//                     ],
//                   ),
//           ),
//         ],
//       ),
//     );
//   }
// }