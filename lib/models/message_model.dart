import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final String? mediaUrl;
  final String messageType; // 'text' | 'image'
  final DateTime timestamp;
  final bool seen;
  final Map<String, String> reactions; // userId -> emoji string
  final Map<String, dynamic>? replyTo; // { 'messageId': ..., 'message': ..., 'senderName': ... }
  final bool deleted;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.mediaUrl,
    required this.messageType,
    required this.timestamp,
    required this.seen,
    required this.reactions,
    this.replyTo,
    this.deleted = false,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MessageModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      receiverId: data['receiverId'] ?? '',
      message: data['message'] ?? '',
      mediaUrl: data['mediaUrl'],
      messageType: data['messageType'] ?? 'text',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      seen: data['seen'] ?? false,
      reactions: Map<String, String>.from(data['reactions'] ?? {}),
      replyTo: data['replyTo'],
      deleted: data['deleted'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'mediaUrl': mediaUrl,
      'messageType': messageType,
      'timestamp': FieldValue.serverTimestamp(),
      'seen': seen,
      'reactions': reactions,
      'replyTo': replyTo,
      'deleted': deleted,
    };
  }
}
