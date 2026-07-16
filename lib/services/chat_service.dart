import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/message_model.dart';
import '../models/status_model.dart';

class ChatService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  String getChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort();
    return ids.join("_");
  }

  Stream<DocumentSnapshot> getLastMessage(
      String currentUserId,
      String otherUserId,
      ) {
    return firestore
        .collection("chats")
        .doc(getChatId(currentUserId, otherUserId))
        .snapshots();
  }

  // Set typing state
  Future<void> setTypingState(String chatId, String userId, bool isTyping) async {
    await firestore.collection("chats").doc(chatId).set({
      "typing": {
        userId: isTyping,
      }
    }, SetOptions(merge: true));
  }

  // Send message (Text)
  Future<void> sendMessage({
    required String receiverId,
    required String message,
    Map<String, dynamic>? replyTo,
    int? selfDestructDuration,
  }) async {
    final currentUserId = auth.currentUser!.uid;
    final chatId = getChatId(currentUserId, receiverId);

    // Get current user's name
    final userDoc = await firestore.collection("users").doc(currentUserId).get();
    final senderName = userDoc.data()?["name"] ?? "User";

    // Get receiver's name
    final recDoc = await firestore.collection("users").doc(receiverId).get();
    final receiverName = recDoc.data()?["name"] ?? "User";

    final docRef = firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc();

    final msg = MessageModel(
      id: docRef.id,
      senderId: currentUserId,
      receiverId: receiverId,
      message: message,
      messageType: 'text',
      timestamp: DateTime.now(),
      seen: false,
      reactions: {},
      replyTo: replyTo,
      selfDestructDuration: selfDestructDuration,
    );

    await docRef.set(msg.toMap());

    // Update last message in Chat List info
    await firestore.collection("chats").doc(chatId).set({
      "participants": [currentUserId, receiverId],
      "participantNames": {
        currentUserId: senderName,
        receiverId: receiverName,
      },
      "lastMessage": message,
      "lastMessageTime": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Send image message
  Future<void> sendImageMessage({
    required String receiverId,
    required String imageUrl,
    String? caption,
    Map<String, dynamic>? replyTo,
    int? selfDestructDuration,
  }) async {
    final currentUserId = auth.currentUser!.uid;
    final chatId = getChatId(currentUserId, receiverId);

    final userDoc = await firestore.collection("users").doc(currentUserId).get();
    final senderName = userDoc.data()?["name"] ?? "User";

    final recDoc = await firestore.collection("users").doc(receiverId).get();
    final receiverName = recDoc.data()?["name"] ?? "User";

    final docRef = firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc();

    final msg = MessageModel(
      id: docRef.id,
      senderId: currentUserId,
      receiverId: receiverId,
      message: caption ?? "📷 Photo",
      mediaUrl: imageUrl,
      messageType: 'image',
      timestamp: DateTime.now(),
      seen: false,
      reactions: {},
      replyTo: replyTo,
      selfDestructDuration: selfDestructDuration,
    );

    await docRef.set(msg.toMap());

    await firestore.collection("chats").doc(chatId).set({
      "participants": [currentUserId, receiverId],
      "participantNames": {
        currentUserId: senderName,
        receiverId: receiverName,
      },
      "lastMessage": "📷 Photo",
      "lastMessageTime": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Send video message
  Future<void> sendVideoMessage({
    required String receiverId,
    required String videoUrl,
    String? caption,
    Map<String, dynamic>? replyTo,
    int? selfDestructDuration,
  }) async {
    final currentUserId = auth.currentUser!.uid;
    final chatId = getChatId(currentUserId, receiverId);

    final userDoc = await firestore.collection("users").doc(currentUserId).get();
    final senderName = userDoc.data()?["name"] ?? "User";

    final recDoc = await firestore.collection("users").doc(receiverId).get();
    final receiverName = recDoc.data()?["name"] ?? "User";

    final docRef = firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc();

    final msg = MessageModel(
      id: docRef.id,
      senderId: currentUserId,
      receiverId: receiverId,
      message: caption ?? "🎥 Video",
      mediaUrl: videoUrl,
      messageType: 'video',
      timestamp: DateTime.now(),
      seen: false,
      reactions: {},
      replyTo: replyTo,
      selfDestructDuration: selfDestructDuration,
    );

    await docRef.set(msg.toMap());

    await firestore.collection("chats").doc(chatId).set({
      "participants": [currentUserId, receiverId],
      "participantNames": {
        currentUserId: senderName,
        receiverId: receiverName,
      },
      "lastMessage": "🎥 Video",
      "lastMessageTime": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Send voice note message
  Future<void> sendVoiceMessage({
    required String receiverId,
    required String voiceUrl,
    required int duration,
    int? selfDestructDuration,
    Map<String, dynamic>? replyTo,
  }) async {
    final currentUserId = auth.currentUser!.uid;
    final chatId = getChatId(currentUserId, receiverId);

    final userDoc = await firestore.collection("users").doc(currentUserId).get();
    final senderName = userDoc.data()?["name"] ?? "User";

    final recDoc = await firestore.collection("users").doc(receiverId).get();
    final receiverName = recDoc.data()?["name"] ?? "User";

    final docRef = firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc();

    final msg = MessageModel(
      id: docRef.id,
      senderId: currentUserId,
      receiverId: receiverId,
      message: "🎤 Voice Message (${duration}s)",
      mediaUrl: voiceUrl,
      messageType: 'voice',
      timestamp: DateTime.now(),
      seen: false,
      reactions: {},
      replyTo: replyTo,
      selfDestructDuration: selfDestructDuration,
      duration: duration,
    );

    await docRef.set(msg.toMap());

    await firestore.collection("chats").doc(chatId).set({
      "participants": [currentUserId, receiverId],
      "participantNames": {
        currentUserId: senderName,
        receiverId: receiverName,
      },
      "lastMessage": "🎤 Voice Message",
      "lastMessageTime": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Upload file (images/videos) to Firebase Storage
  Future<String> uploadFile(File file, String folder, String extension) async {
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.$extension";
    final ref = storage.ref().child(folder).child(fileName);
    final uploadTask = await ref.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  // Upload profile or chat images to Firebase Storage
  Future<String> uploadImage(File file, String folder) async {
    return uploadFile(file, folder, "jpg");
  }

  // Delete message
  Future<void> deleteMessage(String chatId, String messageId, bool forEveryone) async {
    if (forEveryone) {
      await firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .update({
        "message": "🚫 This message was deleted",
        "deleted": true,
        "mediaUrl": FieldValue.delete(),
        "messageType": "text",
      });

      // Update last message preview if this was the latest message
      final lastMsgQuery = await firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .orderBy("timestamp", descending: true)
          .limit(1)
          .get();
      
      if (lastMsgQuery.docs.isNotEmpty && lastMsgQuery.docs.first.id == messageId) {
        await firestore.collection("chats").doc(chatId).update({
          "lastMessage": "🚫 This message was deleted",
        });
      }
    } else {
      // Local delete
      await firestore
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .doc(messageId)
          .delete();
    }
  }

  // Add/remove emoji reaction
  Future<void> updateReaction(
      String chatId, String messageId, String userId, String? emoji) async {
    final docRef = firestore
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .doc(messageId);

    if (emoji == null) {
      await docRef.update({
        "reactions.$userId": FieldValue.delete(),
      });
    } else {
      await docRef.update({
        "reactions.$userId": emoji,
      });
    }
  }

  // Status (Stories) Upload
  Future<void> uploadStatus({
    String? text,
    String? mediaUrl,
    int backgroundColor = 0xFF008069,
    String? caption,
  }) async {
    final currentUserId = auth.currentUser!.uid;

    final userDoc = await firestore.collection("users").doc(currentUserId).get();
    final userName = userDoc.data()?["name"] ?? "User";
    final userPhotoUrl = userDoc.data()?["photoUrl"] ?? "";

    final statusId = DateTime.now().millisecondsSinceEpoch.toString();
    final statusItem = StatusItem(
      id: statusId,
      text: text,
      mediaUrl: mediaUrl,
      backgroundColor: backgroundColor,
      timestamp: DateTime.now(),
      caption: caption,
    );

    final docRef = firestore.collection("statuses").doc(currentUserId);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      final currentData = docSnapshot.data() as Map<String, dynamic>;
      final rawItems = currentData["items"] as List<dynamic>? ?? [];
      
      // Filter out statuses older than 24 hours
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      List<Map<String, dynamic>> updatedItems = [];
      
      for (var rawItem in rawItems) {
        final parsedItem = StatusItem.fromMap(Map<String, dynamic>.from(rawItem));
        if (parsedItem.timestamp.isAfter(cutoff)) {
          updatedItems.add(rawItem);
        }
      }

      updatedItems.add(statusItem.toMap());

      await docRef.update({
        "userName": userName,
        "userPhotoUrl": userPhotoUrl,
        "items": updatedItems,
      });
    } else {
      await docRef.set({
        "userName": userName,
        "userPhotoUrl": userPhotoUrl,
        "items": [statusItem.toMap()],
      });
    }
  }

  // Fetch all active, unexpired statuses from all users
  Stream<List<UserStatus>> getStatusesStream() {
    return firestore.collection("statuses").snapshots().map((snapshot) {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
      
      return snapshot.docs.map((doc) {
        final status = UserStatus.fromFirestore(doc);
        final activeItems = status.items
            .where((item) => item.timestamp.isAfter(cutoff))
            .toList();
        
        return UserStatus(
          uid: status.uid,
          userName: status.userName,
          userPhotoUrl: status.userPhotoUrl,
          items: activeItems,
        );
      }).where((status) => status.items.isNotEmpty).toList();
    });
  }
}