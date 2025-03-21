import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverDetailScreen extends StatefulWidget {
  final Map<String, dynamic> driver;

  const DriverDetailScreen({
    Key? key,
    required this.driver,
  }) : super(key: key);

  @override
  State<DriverDetailScreen> createState() => _DriverDetailScreenState();
}

class _DriverDetailScreenState extends State<DriverDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  // Rating state
  double _rating = 0;
  bool _ratingSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadDriverRating();

    // Set initial rating value
    if (widget.driver.containsKey('rating')) {
      _rating = (widget.driver['rating'] as num).toDouble();
    }
  }

  // Load driver rating
  Future<void> _loadDriverRating() async {
    try {
      DocumentSnapshot driverDoc = await _firestore
          .collection('drivers')
          .doc(widget.driver['id'])
          .get();

      if (driverDoc.exists) {
        Map<String, dynamic> data = driverDoc.data() as Map<String, dynamic>;

        if (data.containsKey('rating')) {
          setState(() {
            _rating = (data['rating'] as num).toDouble();
          });
        }
      }
    } catch (e) {
      print('Error loading driver rating: $e');
    }
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

  // Open WhatsApp chat
  Future<void> _openWhatsApp(String phoneNumber) async {
    // Remove any non-numeric characters from the phone number
    String cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // If the phone number doesn't start with a country code, add +91 for India
    if (!cleanPhoneNumber.startsWith('+')) {
      cleanPhoneNumber = '91$cleanPhoneNumber';
    }

    String whatsappUrl = "https://wa.me/$cleanPhoneNumber";

    try {
      await launchUrl(Uri.parse(whatsappUrl));
    } catch (e) {
      print('Could not launch WhatsApp: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open WhatsApp'),
        ),
      );
    }
  }

  // Open map to show driver location
  Future<void> _openMap() async {
    if (widget.driver['location'] != null) {
      final GeoPoint location = widget.driver['location'] as GeoPoint;
      final double lat = location.latitude;
      final double lng = location.longitude;

      final String googleMapsUrl = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

      try {
        await launchUrl(Uri.parse(googleMapsUrl));
      } catch (e) {
        print('Could not open map: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open map'),
          ),
        );
      }
    }
  }

  // Send current location to driver
  Future<void> _sendLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user location
      String? userId = _auth.currentUser?.uid;

      if (userId != null) {
        DocumentSnapshot userLocationDoc = await _firestore
            .collection('user_locations')
            .doc(userId)
            .get();

        if (userLocationDoc.exists) {
          Map<String, dynamic> data = userLocationDoc.data() as Map<String, dynamic>;

          // Create a new request in Firestore
          await _firestore.collection('ride_requests').add({
            'userId': userId,
            'driverId': widget.driver['id'],
            'userLocation': GeoPoint(
              data['latitude'] as double,
              data['longitude'] as double
            ),
            'status': 'pending',
            'timestamp': FieldValue.serverTimestamp(),
            'userName': _auth.currentUser?.displayName ?? 'User',
            'driverName': widget.driver['name'] ?? 'Driver'
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Request sent successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not find your location'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Submit rating to Firestore
  Future<void> _submitRating(double rating) async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? userId = _auth.currentUser?.uid;
      String driverId = widget.driver['id'];

      if (userId != null) {
        // Store the rating in a new collection
        await _firestore.collection('driver_ratings').add({
          'userId': userId,
          'driverId': driverId,
          'rating': rating,
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update the driver's average rating
        QuerySnapshot ratingsSnapshot = await _firestore
            .collection('driver_ratings')
            .where('driverId', isEqualTo: driverId)
            .get();

        double totalRating = 0;
        int ratingCount = ratingsSnapshot.docs.length;

        for (var doc in ratingsSnapshot.docs) {
          totalRating += (doc['rating'] as num).toDouble();
        }

        double averageRating = totalRating / ratingCount;

        // Update the driver's rating in the drivers collection
        await _firestore.collection('drivers').doc(driverId).update({
          'rating': averageRating,
        });

        setState(() {
          _rating = averageRating;
          _ratingSubmitted = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rating submitted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error submitting rating: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = widget.driver['name'] ?? 'Unknown';
    final String phone = widget.driver['phone'] ?? 'No phone';
    final String vehicleNumber = widget.driver['vehicleNumber'] ?? 'Not available';
    final String profileImage = widget.driver['profileImage'] ?? '';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.grey[100],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Driver profile section
            Center(
              child: Column(
                children: [
                  // Profile image
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: profileImage.isNotEmpty
                          ? DecorationImage(
                        image: NetworkImage(profileImage),
                        fit: BoxFit.cover,
                      )
                          : const DecorationImage(
                        image: AssetImage('assets/default_profile.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Driver name
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Contact buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Call button
                      IconButton(
                        onPressed: () => _makePhoneCall(phone),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone,
                            color: Colors.white,
                          ),
                        ),
                        iconSize: 40,
                      ),
                      const SizedBox(width: 20),
                      // WhatsApp button
                      IconButton(
                        onPressed: () => _openWhatsApp(phone),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat,
                            color: Colors.white,
                          ),
                        ),
                        iconSize: 40,
                      ),
                      const SizedBox(width: 20),
                      // Location button
                      IconButton(
                        onPressed: _openMap,
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.white,
                          ),
                        ),
                        iconSize: 40,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            // Driver info section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Name field
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Name : $name',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Phone field
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Phone : $phone',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Vehicle number field
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Vehicle no : $vehicleNumber',
                      style: const TextStyle(
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Send location button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _sendLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        foregroundColor: Colors.black,
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text(
                        'Send Request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Rating section
                  Row(
                    children: [
                      const Text(
                        'Rating',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Star rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(5, (index) {
                      return GestureDetector(
                        onTap: () {
                          if (!_ratingSubmitted) {
                            setState(() {
                              _rating = index + 1.0;
                            });
                            _submitRating(_rating);
                          }
                        },
                        child: Icon(
                          index < _rating.floor() ? Icons.star : Icons.star_border,
                          size: 30,
                          color: _ratingSubmitted ? Colors.grey : Colors.amber,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}