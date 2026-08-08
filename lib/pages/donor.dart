import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:foodshare/pages/availability.dart';
import 'auth_service.dart';
import 'locationpickerpage.dart';

const _donorGreen = Color(0xFF4CAF50);

class DonorPage extends StatefulWidget {
  const DonorPage({super.key});

  @override
  State<DonorPage> createState() => _DonorPageState();
}

class _DonorPageState extends State<DonorPage>
    with SingleTickerProviderStateMixin {
  final _db = FirebaseFirestore.instance;
  late final TabController _tabController;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _email => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<FoodPost>> get _postsStream => _db
      .collection('posts')
      .where('donorId', isEqualTo: _uid)
      .orderBy('timestamp', descending: true)
      .snapshots()
      .map((snap) => snap.docs.map((d) => FoodPost.fromDoc(d)).toList());

  Future<void> _createPost(
    String name,
    int quantity,
    String locationText,
    double? lat,
    double? lng,
  ) async {
    await _db.collection('posts').add({
      'donorId': _uid,
      'donorEmail': _email,
      'name': name,
      'quantity': quantity,
      'location': locationText,
      'latitude': lat,
      'longitude': lng,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'available',
      'receiverId': null,
      'receiverName': null,
    });
  }

  Future<void> _markPickedUp(FoodPost post, String receiverName) async {
    await _db.collection('posts').doc(post.id).update({
      'status': 'pickedUp',
      'receiverName': receiverName,
    });
  }

  void _showMarkPickedUpDialog(FoodPost post) {
    final controller = TextEditingController(text: post.receiverName ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Picked Up'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Receiver's name"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                _markPickedUp(post, controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(FoodPost post) async {
    await _db.collection('posts').doc(post.id).delete();
  }

  void _confirmDelete(FoodPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: Text(
          'This will permanently remove "${post.name}". This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(post);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openAddDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddAvailabilityDialog(onSubmit: _createPost),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(email: _email, onLogout: () => AuthService().signOut()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _QuickActionCard(
                icon: Icons.add,
                iconColor: _donorGreen,
                borderColor: Colors.green[300]!,
                title: 'Post Surplus Food',
                onTap: _openAddDialog,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: StreamBuilder<List<FoodPost>>(
                    stream: _postsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _ErrorState(error: snapshot.error.toString());
                      }
                      final posts = snapshot.data;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TabBar(
                            controller: _tabController,
                            labelColor: _donorGreen,
                            unselectedLabelColor: Colors.grey[600],
                            indicatorColor: _donorGreen,
                            indicatorWeight: 3,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                            tabs: const [
                              Tab(text: 'Overview'),
                              Tab(text: 'My Donations'),
                            ],
                          ),
                          Expanded(
                            child: posts == null
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : TabBarView(
                                    controller: _tabController,
                                    children: [
                                      _OverviewTab(posts: posts),
                                      _MyDonationsTab(
                                        posts: posts,
                                        onMarkPickedUp: _showMarkPickedUpDialog,
                                        onDelete: _confirmDelete,
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
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
      color: _donorGreen,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Donor Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  email,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onLogout,
            style: TextButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.2),
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
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 32),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: iconColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final List<FoodPost> posts;
  const _OverviewTab({required this.posts});

  @override
  Widget build(BuildContext context) {
    final total = posts.length;
    final completed = posts
        .where((p) => p.status == PostStatus.completed)
        .length;
    final active = posts.where((p) => p.status != PostStatus.completed).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatColumn(value: total, label: 'Total Posts', color: _donorGreen),
          _StatColumn(
            value: completed,
            label: 'Completed',
            color: Colors.deepOrange,
          ),
          _StatColumn(value: active, label: 'Active', color: Colors.blue),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _StatColumn({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
      ],
    );
  }
}

class _MyDonationsTab extends StatelessWidget {
  final List<FoodPost> posts;
  final void Function(FoodPost) onMarkPickedUp;
  final void Function(FoodPost) onDelete;

  const _MyDonationsTab({
    required this.posts,
    required this.onMarkPickedUp,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return const _EmptyState(
        message: 'No posts yet. Tap "Post Surplus Food" to get started.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        final canMarkPickedUp =
            post.status == PostStatus.available ||
            post.status == PostStatus.accepted;
        return FoodPostCard(
          post: post,
          actionLabel: canMarkPickedUp ? 'Mark as Picked Up' : null,
          onAction: canMarkPickedUp ? () => onMarkPickedUp(post) : null,
          onDelete: () => onDelete(post),
        );
      },
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: Colors.grey[400]),
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

class _AddAvailabilityDialog extends StatefulWidget {
  final Future<void> Function(
    String name,
    int quantity,
    String location,
    double? lat,
    double? lng,
  )
  onSubmit;
  const _AddAvailabilityDialog({required this.onSubmit});

  @override
  State<_AddAvailabilityDialog> createState() => _AddAvailabilityDialogState();
}

class _AddAvailabilityDialogState extends State<_AddAvailabilityDialog> {
  final _foodTypeController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  double? _lat;
  double? _lng;
  bool _showQuantityError = false;

  Future<void> _pickLocation() async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (result != null) {
      setState(() {
        _lat = result.latitude;
        _lng = result.longitude;
        _locationController.text = '${result.latitude}, ${result.longitude}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Post Surplus Food',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Field(label: 'Food Type', controller: _foodTypeController),
            const SizedBox(height: 16),
            _Field(
              label: 'Quantity',
              controller: _quantityController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            const Text(
              'Pickup Location',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickLocation,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.map, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _locationController.text.isEmpty
                            ? 'Tap to select on map'
                            : _locationController.text,
                        style: TextStyle(
                          color: _locationController.text.isEmpty
                              ? Colors.grey[600]
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_showQuantityError) ...[
              const SizedBox(height: 8),
              const Text(
                'Enter a quantity greater than 0',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final quantity = int.tryParse(_quantityController.text);
                  final quantityValid = quantity != null && quantity > 0;
                  setState(() => _showQuantityError = !quantityValid);
                  if (_foodTypeController.text.isNotEmpty &&
                      _locationController.text.isNotEmpty &&
                      quantityValid) {
                    await widget.onSubmit(
                      _foodTypeController.text,
                      quantity!,
                      _locationController.text,
                      _lat,
                      _lng,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _donorGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Post Food', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _foodTypeController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    super.dispose();
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
