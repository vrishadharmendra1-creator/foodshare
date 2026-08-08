import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum PostStatus { available, accepted, pickedUp, completed }

PostStatus postStatusFromString(String value) {
  switch (value) {
    case 'accepted':
      return PostStatus.accepted;
    case 'pickedUp':
      return PostStatus.pickedUp;
    case 'completed':
      return PostStatus.completed;
    default:
      return PostStatus.available;
  }
}

String postStatusToString(PostStatus status) => status.name;

class FoodPost {
  final String? id;
  final String donorId;
  final String donorEmail;
  final String name;
  final int quantity;
  final String location;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final PostStatus status;
  final String? receiverId;
  final String? receiverName;

  FoodPost({
    this.id,
    required this.donorId,
    required this.donorEmail,
    required this.name,
    required this.quantity,
    required this.location,
    this.latitude,
    this.longitude,
    required this.timestamp,
    this.status = PostStatus.available,
    this.receiverId,
    this.receiverName,
  });

  factory FoodPost.fromDoc(DocumentSnapshot doc) {
    final json = doc.data() as Map<String, dynamic>;
    return FoodPost(
      id: doc.id,
      donorId: json['donorId'] ?? '',
      donorEmail: json['donorEmail'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      location: json['location'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: postStatusFromString(json['status'] ?? 'available'),
      receiverId: json['receiverId'],
      receiverName: json['receiverName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'donorId': donorId,
      'donorEmail': donorEmail,
      'name': name,
      'quantity': quantity,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': postStatusToString(status),
      'receiverId': receiverId,
      'receiverName': receiverName,
    };
  }
}

class FoodPostCard extends StatelessWidget {
  final FoodPost post;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDelete;

  const FoodPostCard({
    super.key,
    required this.post,
    this.actionLabel,
    this.onAction,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  post.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(status: post.status),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.grey[500],
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Qty: ${post.quantity}',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: Colors.grey[500],
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  post.location,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (post.receiverName != null) ...[
            const SizedBox(height: 4),
            Text(
              'Receiver: ${post.receiverName}',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green[700],
                  side: BorderSide(color: Colors.green[200]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PostStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    late String label;
    late Color color;
    switch (status) {
      case PostStatus.available:
        label = 'Available';
        color = Colors.green;
        break;
      case PostStatus.accepted:
        label = 'Reserved';
        color = Colors.orange;
        break;
      case PostStatus.pickedUp:
        label = 'Picked up';
        color = Colors.blue;
        break;
      case PostStatus.completed:
        label = 'Completed';
        color = Colors.grey;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
