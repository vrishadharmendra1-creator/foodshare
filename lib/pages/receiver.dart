import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' hide Position;
import 'package:foodshare/pages/availability.dart';
import 'auth_service.dart';

const _orange = Color(0xFFE8590C);

class ReceiverPage extends StatefulWidget {
  const ReceiverPage({super.key});

  @override
  State<ReceiverPage> createState() => _ReceiverPageState();
}

class _ReceiverPageState extends State<ReceiverPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  final _authService = AuthService();
  late final TabController _tabController;

  static const double _nearbyRadiusKm = 15;

  double? _userLat;
  double? _userLng;
  bool _locationLoading = true;

  // Cached once on load and stamped onto each accepted pickup so the
  // donor has a number to call.
  String? _receiverPhone;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUserLocation();
    _loadReceiverPhone();
  }

  Future<void> _loadReceiverPhone() async {
    final phone = await _authService.getUserPhone(_uid);
    if (mounted) setState(() => _receiverPhone = phone);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    final ok = await _setupPositionTracking();
    if (!ok) {
      if (mounted) setState(() => _locationLoading = false);
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLat = pos.latitude;
          _userLng = pos.longitude;
          _locationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locationLoading = false);
    }
  }

  Future<bool> _setupPositionTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Stream<List<FoodPost>> get _nearbyStream => _db
      .collection('posts')
      .where('status', isEqualTo: 'available')
      .snapshots()
      .map((snap) {
        var posts = snap.docs.map((d) => FoodPost.fromDoc(d)).toList();
        if (_userLat != null && _userLng != null) {
          posts = posts.where((p) {
            // Keep posts with no coordinates on file rather than hiding
            // them -- we simply can't tell how far away they are.
            if (p.latitude == null || p.longitude == null) return true;
            final km =
                Geolocator.distanceBetween(
                  _userLat!,
                  _userLng!,
                  p.latitude!,
                  p.longitude!,
                ) /
                1000;
            return km <= _nearbyRadiusKm;
          }).toList();
        }
        posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return posts;
      });

  Stream<List<FoodPost>> get _myPostsStream => _db
      .collection('posts')
      .where('receiverId', isEqualTo: _uid)
      .snapshots()
      .map((snap) {
        final posts = snap.docs.map((d) => FoodPost.fromDoc(d)).toList();
        posts.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        return posts;
      });

  Future<void> _acceptPickup(FoodPost post) async {
    final docRef = _db.collection('posts').doc(post.id);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('This donation no longer exists.');
        }
        final currentStatus = snapshot.data()?['status'];
        if (currentStatus != 'available') {
          throw Exception('Someone already claimed this donation just now.');
        }
        transaction.update(docRef, {
          'status': 'accepted',
          'receiverId': _uid,
          'receiverName': _email,
          'receiverPhone': _receiverPhone,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _cancelPickup(FoodPost post) async {
    final docRef = _db.collection('posts').doc(post.id);
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;
        final currentStatus = snapshot.data()?['status'];
        if (currentStatus != 'accepted') {
          throw Exception('This pickup can no longer be canceled.');
        }
        transaction.update(docRef, {
          'status': 'available',
          'receiverId': null,
          'receiverName': null,
          'receiverPhone': null,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _verifyPickup(FoodPost post) async {
    await _db.collection('posts').doc(post.id).update({'status': 'completed'});
  }

  Future<void> _openDirections(FoodPost post) async {
    Uri uri;
    if (post.latitude != null && post.longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${post.latitude},${post.longitude}',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(post.location)}',
      );
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _Header(email: _email, onLogout: () => AuthService().signOut()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.map_outlined,
                    iconColor: Colors.green[700]!,
                    borderColor: Colors.green[300]!,
                    title: 'Meal Map',
                    subtitle: 'Find free meals nearby',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _MealMapPage(nearbyStream: _nearbyStream),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.verified_outlined,
                    iconColor: Colors.deepPurple,
                    borderColor: Colors.deepPurple[200]!,
                    title: 'Verify Pickups',
                    subtitle: null,
                    onTap: () => _tabController.animateTo(2),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: StreamBuilder<List<FoodPost>>(
                stream: _nearbyStream,
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;
                  return TabBar(
                    controller: _tabController,
                    labelColor: _orange,
                    unselectedLabelColor: Colors.grey[600],
                    indicatorColor: _orange,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    tabs: [
                      Tab(text: 'Nearby Donations ($count)'),
                      const Tab(text: 'My Pickups'),
                      const Tab(text: 'Verifications'),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _NearbyDonationsTab(
                    stream: _nearbyStream,
                    onAccept: _acceptPickup,
                    onDirections: _openDirections,
                    userLat: _userLat,
                    userLng: _userLng,
                    locationLoading: _locationLoading,
                    radiusKm: _nearbyRadiusKm,
                  ),
                  _MyPickupsTab(
                    stream: _myPostsStream,
                    onDirections: _openDirections,
                    onCancel: _cancelPickup,
                  ),
                  _VerificationsTab(
                    stream: _myPostsStream,
                    onVerify: _verifyPickup,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String email;
  final VoidCallback onLogout;
  const _Header({required this.email, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _orange,
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 16,
        20,
        20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receiver Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onLogout,
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.15),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 28),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: iconColor,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NearbyDonationsTab extends StatelessWidget {
  final Stream<List<FoodPost>> stream;
  final Future<void> Function(FoodPost) onAccept;
  final Future<void> Function(FoodPost) onDirections;
  final double? userLat;
  final double? userLng;
  final bool locationLoading;
  final double radiusKm;

  const _NearbyDonationsTab({
    required this.stream,
    required this.onAccept,
    required this.onDirections,
    required this.userLat,
    required this.userLng,
    required this.locationLoading,
    required this.radiusKm,
  });

  String? _distanceLabel(FoodPost post) {
    if (userLat == null ||
        userLng == null ||
        post.latitude == null ||
        post.longitude == null) {
      return null;
    }
    final km =
        Geolocator.distanceBetween(
          userLat!,
          userLng!,
          post.latitude!,
          post.longitude!,
        ) /
        1000;
    if (km < 0.1) return 'Very close';
    return '${km.toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodPost>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data!;
        final showLocationNotice = userLat == null && !locationLoading;

        if (posts.isEmpty) {
          return _EmptyState(
            message: showLocationNotice
                ? 'No nearby donations right now. Enable location access '
                      'to see donations within ${radiusKm.toStringAsFixed(0)} km.'
                : 'No donations within ${radiusKm.toStringAsFixed(0)} km right now. '
                      'Check back soon!',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (showLocationNotice)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Location access is off, so these aren\'t filtered by '
                  'distance yet.',
                  style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                ),
              ),
            ...posts.map(
              (post) => _DonationCard(
                post: post,
                badgeLabel: 'Available',
                badgeColor: Colors.green,
                primaryLabel: 'Accept Pickup',
                onPrimary: () => onAccept(post),
                onDirections: () => onDirections(post),
                distanceLabel: _distanceLabel(post),
                // No phone number here: a donation is still unclaimed on
                // this tab, so the donor's number stays hidden until a
                // receiver actually accepts the pickup (see My Pickups).
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MyPickupsTab extends StatelessWidget {
  final Stream<List<FoodPost>> stream;
  final Future<void> Function(FoodPost) onDirections;
  final Future<void> Function(FoodPost) onCancel;

  const _MyPickupsTab({
    required this.stream,
    required this.onDirections,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodPost>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data!
            .where((p) => p.status == PostStatus.accepted)
            .toList();
        if (posts.isEmpty) {
          return const _EmptyState(
            message: 'No active pickups. Accept a donation to see it here.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, i) {
            final post = posts[i];
            return _DonationCard(
              post: post,
              badgeLabel: 'Accepted',
              badgeColor: Colors.orange,
              primaryLabel: 'Get Directions',
              onPrimary: () => onDirections(post),
              onDirections: null,
              secondaryLabel: 'Cancel Pickup',
              onSecondary: () => _confirmCancel(context, post),
              phoneNumber: post.donorPhone,
              phoneLabel: 'Call Donor',
            );
          },
        );
      },
    );
  }

  void _confirmCancel(BuildContext context, FoodPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this pickup?'),
        content: Text(
          'This will release "${post.name}" back to other receivers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onCancel(post);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Cancel pickup'),
          ),
        ],
      ),
    );
  }
}

class _VerificationsTab extends StatelessWidget {
  final Stream<List<FoodPost>> stream;
  final Future<void> Function(FoodPost) onVerify;

  const _VerificationsTab({required this.stream, required this.onVerify});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FoodPost>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(error: snapshot.error.toString());
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final pending = snapshot.data!
            .where((p) => p.status == PostStatus.pickedUp)
            .toList();
        final completed = snapshot.data!
            .where((p) => p.status == PostStatus.completed)
            .toList();
        if (pending.isEmpty && completed.isEmpty) {
          return const _EmptyState(
            message:
                'Nothing to verify yet. Once a donor marks your pickup as '
                'picked up, it will show here for you to confirm.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (pending.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Awaiting your confirmation',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...pending.map(
                (post) => _DonationCard(
                  post: post,
                  badgeLabel: 'Picked up',
                  badgeColor: Colors.blue,
                  primaryLabel: 'Verify Pickup',
                  onPrimary: () => onVerify(post),
                  onDirections: null,
                ),
              ),
            ],
            if (completed.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  'Completed',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...completed.map(
                (post) => _DonationCard(
                  post: post,
                  badgeLabel: 'Completed',
                  badgeColor: Colors.grey,
                  primaryLabel: null,
                  onPrimary: null,
                  onDirections: null,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DonationCard extends StatelessWidget {
  final FoodPost post;
  final String badgeLabel;
  final Color badgeColor;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onDirections;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? distanceLabel;
  final String? phoneNumber;
  final String? phoneLabel;

  const _DonationCard({
    required this.post,
    required this.badgeLabel,
    required this.badgeColor,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onDirections,
    this.secondaryLabel,
    this.onSecondary,
    this.distanceLabel,
    this.phoneNumber,
    this.phoneLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  post.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: _orange,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 16, color: _orange),
              const SizedBox(width: 6),
              Text('${post.quantity} portions'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 16, color: _orange),
              const SizedBox(width: 6),
              Expanded(
                child: Text(post.location, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          if (distanceLabel != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 22),
                Text(
                  distanceLabel!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
          if (post.receiverName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Receiver: ${post.receiverName}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          if (primaryLabel != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onPrimary,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      primaryLabel!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (onDirections != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.navigation_outlined),
                      color: Colors.grey[700],
                      onPressed: onDirections,
                    ),
                  ),
                ],
              ],
            ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[700],
                    side: BorderSide(color: Colors.red[200]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(secondaryLabel!),
                ),
              ),
            ],
          ],
          if (phoneNumber != null && phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => launchPhoneDialer(context, phoneNumber!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  side: BorderSide(color: Colors.blue[200]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.call, size: 18),
                label: Text(phoneLabel ?? 'Call'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Error: $error',
          style: const TextStyle(color: Colors.red),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _MealMapPage extends StatefulWidget {
  final Stream<List<FoodPost>> nearbyStream;
  const _MealMapPage({required this.nearbyStream});

  @override
  State<_MealMapPage> createState() => _MealMapPageState();
}

class _MealMapPageState extends State<_MealMapPage> {
  MapboxMap? _mapController;
  PointAnnotationManager? _annotationManager;

  Position? _userPosition;
  bool _locationLoading = true;
  String? _locationError;

  List<FoodPost> _plottedPosts = [];

  Position? _fallbackFromPosts(List<FoodPost> posts) {
    for (final p in posts) {
      if (p.latitude != null && p.longitude != null) {
        return Position(p.longitude!, p.latitude!);
      }
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
  }

  Future<void> _loadUserLocation() async {
    final ok = await _setupPositionTracking();
    if (!ok) {
      if (mounted) {
        setState(() {
          _locationError = 'Location permission denied';
          _locationLoading = false;
        });
      }
      return;
    }
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userPosition = Position(pos.longitude, pos.latitude);
          _locationLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Could not get your location';
          _locationLoading = false;
        });
      }
    }
  }

  Future<bool> _setupPositionTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapController = controller;
    _annotationManager = await controller.annotations
        .createPointAnnotationManager();
    await controller.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    );
  }

  Future<void> _plotDonations(List<FoodPost> posts) async {
    if (_annotationManager == null) return;
    // Avoid re-plotting the exact same set of posts on every rebuild.
    if (posts.length == _plottedPosts.length &&
        posts.every((p) => _plottedPosts.any((q) => q.id == p.id))) {
      return;
    }
    _plottedPosts = posts;
    await _annotationManager!.deleteAll();
    final options = posts
        .where((p) => p.latitude != null && p.longitude != null)
        .map(
          (p) => PointAnnotationOptions(
            geometry: Point(coordinates: Position(p.longitude!, p.latitude!)),
            textField: '🍽️',
            textSize: 26,
          ),
        )
        .toList();
    if (options.isNotEmpty) {
      await _annotationManager!.createMulti(options);
    }
  }

  Future<void> _flyToPost(FoodPost post) async {
    if (_mapController == null ||
        post.latitude == null ||
        post.longitude == null) {
      return;
    }
    await _mapController!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(post.longitude!, post.latitude!)),
        zoom: 16,
      ),
      MapAnimationOptions(duration: 700),
    );
  }

  String? _distanceLabel(FoodPost post) {
    if (_userPosition == null ||
        post.latitude == null ||
        post.longitude == null) {
      return null;
    }
    final meters = Geolocator.distanceBetween(
      _userPosition!.lat.toDouble(),
      _userPosition!.lng.toDouble(),
      post.latitude!,
      post.longitude!,
    );
    final miles = meters / 1609.34;
    if (miles < 0.1) return 'Very close';
    return '${miles.toStringAsFixed(1)} mi away';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Colors.green[700],
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Back to Dashboard',
                        style: TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Meal Map',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 4),
                    child: Text(
                      'Find free meals and food donations nearby',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<FoodPost>>(
                stream: widget.nearbyStream,
                builder: (context, snapshot) {
                  final posts = snapshot.data ?? [];

                  if (_locationLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Getting your location...'),
                          ],
                        ),
                      ),
                    );
                  }

                  final initialCenter =
                      _userPosition ?? _fallbackFromPosts(posts);

                  // Plot pins whenever the post list changes.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _plotDonations(posts);
                  });

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 280,
                          width: double.infinity,
                          child: Stack(
                            children: [
                              MapWidget(
                                cameraOptions: initialCenter != null
                                    ? CameraOptions(
                                        center: Point(
                                          coordinates: initialCenter,
                                        ),
                                        zoom: 13,
                                      )
                                    : null,
                                onMapCreated: _onMapCreated,
                              ),
                              if (_locationError != null)
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  bottom: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$_locationError — showing donation pins only',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${posts.length} locations nearby',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Nearby Locations',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...posts.map((post) {
                        final distance = _distanceLabel(post);
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _flyToPost(post),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        post.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.my_location,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  post.location,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                if (distance != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    distance,
                                    style: TextStyle(
                                      color: Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
