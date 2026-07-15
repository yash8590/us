import 'package:cloud_firestore/cloud_firestore.dart';

class StatusItem {
  final String id;
  final String? mediaUrl;
  final String? text;
  final int backgroundColor;
  final DateTime timestamp;
  final String? caption;

  StatusItem({
    required this.id,
    this.mediaUrl,
    this.text,
    this.backgroundColor = 0xFF008069,
    required this.timestamp,
    this.caption,
  });

  factory StatusItem.fromMap(Map<String, dynamic> map) {
    return StatusItem(
      id: map['id'] ?? '',
      mediaUrl: map['mediaUrl'],
      text: map['text'],
      backgroundColor: map['backgroundColor'] ?? 0xFF008069,
      timestamp: map['timestamp'] is Timestamp
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.parse(map['timestamp'] as String),
      caption: map['caption'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mediaUrl': mediaUrl,
      'text': text,
      'backgroundColor': backgroundColor,
      'timestamp': Timestamp.fromDate(timestamp),
      'caption': caption,
    };
  }
}

class UserStatus {
  final String uid;
  final String userName;
  final String? userPhotoUrl;
  final List<StatusItem> items;

  UserStatus({
    required this.uid,
    required this.userName,
    this.userPhotoUrl,
    required this.items,
  });

  factory UserStatus.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    List<StatusItem> parsedItems = rawItems
        .map((item) => StatusItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();

    // Sort status items sequentially (oldest displayed first)
    parsedItems.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return UserStatus(
      uid: doc.id,
      userName: data['userName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      items: parsedItems,
    );
  }
}
