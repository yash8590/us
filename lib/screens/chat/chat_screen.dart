import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/message_model.dart';
import '../../services/chat_service.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../widgets/chat_input.dart';
import '../../widgets/message_bubble.dart';
import 'doodle_screen.dart';

class ChatScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final ScrollController _scrollController = ScrollController();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  
  MessageModel? _replyMessage;
  int? _selfDestructDuration;

  StreamSubscription<DocumentSnapshot>? _nudgeSubscription;
  DateTime? _lastNudgeTime;

  @override
  void initState() {
    super.initState();
    _listenForNudges();
  }

  @override
  void dispose() {
    _nudgeSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenForNudges() {
    final chatId = _getChatId();
    _nudgeSubscription = FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data() ?? {};
        final nudgeData = data["nudge"] as Map<String, dynamic>?;
        if (nudgeData != null) {
          final senderId = nudgeData["senderId"] as String?;
          final timestamp = nudgeData["timestamp"] as Timestamp?;

          if (senderId != null && senderId != _currentUser.uid && timestamp != null) {
            final nudgeDateTime = timestamp.toDate();
            if (_lastNudgeTime == null || nudgeDateTime.isAfter(_lastNudgeTime!)) {
              _lastNudgeTime = nudgeDateTime;
              _triggerNudgeEffect();
            }
          }
        }
      }
    });
  }

  void _triggerNudgeEffect() {
    HapticFeedback.vibrate();
    Future.delayed(const Duration(milliseconds: 200), () => HapticFeedback.vibrate());
    Future.delayed(const Duration(milliseconds: 400), () => HapticFeedback.vibrate());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
            const SizedBox(width: 10),
            Text("${widget.receiverName} nudged you! 💖"),
          ],
        ),
        backgroundColor: WAColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendNudge() async {
    final chatId = _getChatId();
    try {
      await FirebaseFirestore.instance.collection("chats").doc(chatId).update({
        "nudge": {
          "senderId": _currentUser.uid,
          "timestamp": FieldValue.serverTimestamp(),
        }
      });

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nudge sent! 💖"),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      // If document doesn't have other fields yet, set them
      await FirebaseFirestore.instance.collection("chats").doc(chatId).set({
        "nudge": {
          "senderId": _currentUser.uid,
          "timestamp": FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
      HapticFeedback.lightImpact();
    }
  }

  String _getChatId() {
    List<String> ids = [_currentUser.uid, widget.receiverId];
    ids.sort();
    return ids.join("_");
  }

  // Real-time unread messages check & update to seen
  Future<void> _markMessagesAsSeen() async {
    final chatId = _getChatId();
    final snapshot = await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .where("receiverId", isEqualTo: _currentUser.uid)
        .where("seen", isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      final data = doc.data();
      final hasTimer = data["selfDestructDuration"] != null;
      if (hasTimer) {
        batch.update(doc.reference, {
          "seen": true,
          "readTime": FieldValue.serverTimestamp(),
        });
      } else {
        batch.update(doc.reference, {"seen": true});
      }
    }
    await batch.commit();
  }

  Future<void> _handleSendMessage(String text) async {
    Map<String, dynamic>? replyData;
    if (_replyMessage != null) {
      // Get reply sender name
      final replySenderName = _replyMessage!.senderId == _currentUser.uid
          ? "You"
          : widget.receiverName;

      replyData = {
        "messageId": _replyMessage!.id,
        "message": _replyMessage!.message,
        "senderName": replySenderName,
      };
    }

    await _chatService.sendMessage(
      receiverId: widget.receiverId,
      message: text,
      replyTo: replyData,
      selfDestructDuration: _selfDestructDuration,
    );

    setState(() {
      _replyMessage = null;
    });
    _scrollToBottom();
  }

  Future<void> _handlePickMedia() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? WAColors.appBarDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: WAColors.primary),
                title: const Text("Upload Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library_rounded, color: WAColors.primary),
                title: const Text("Upload Video"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndSendMedia(false);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickAndSendMedia(bool isPhoto) async {
    try {
      final picker = ImagePicker();
      final XFile? pickedFile = isPhoto
          ? await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 60,
              maxWidth: 800,
            )
          : await picker.pickVideo(
              source: ImageSource.gallery,
              maxDuration: const Duration(minutes: 5),
            );

      if (pickedFile != null) {
        final File file = File(pickedFile.path);

        // Show uploading feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isPhoto ? "Uploading image..." : "Uploading video...")),
        );

        final String fileExtension = isPhoto ? "jpg" : "mp4";
        final String folder = isPhoto ? "chat_images" : "chat_videos";

        // Upload
        final downloadUrl = await _chatService.uploadFile(file, folder, fileExtension);

        Map<String, dynamic>? replyData;
        if (_replyMessage != null) {
          final replySenderName = _replyMessage!.senderId == _currentUser.uid
              ? "You"
              : widget.receiverName;
          replyData = {
            "messageId": _replyMessage!.id,
            "message": _replyMessage!.message,
            "senderName": replySenderName,
          };
        }

        if (isPhoto) {
          await _chatService.sendImageMessage(
            receiverId: widget.receiverId,
            imageUrl: downloadUrl,
            replyTo: replyData,
            selfDestructDuration: _selfDestructDuration,
          );
        } else {
          await _chatService.sendVideoMessage(
            receiverId: widget.receiverId,
            videoUrl: downloadUrl,
            replyTo: replyData,
            selfDestructDuration: _selfDestructDuration,
          );
        }

        setState(() {
          _replyMessage = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Media send failed. Ensure Firebase Storage is enabled. Error: $e")),
      );
    }
  }

  void _handleTypingState(bool isTyping) {
    _chatService.setTypingState(_getChatId(), _currentUser.uid, isTyping);
  }

  Future<void> _handleSendVoiceNote(File file, int duration) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Uploading voice note...")),
      );

      // Upload audio file (folder: chat_voices, extension: m4a)
      final downloadUrl = await _chatService.uploadFile(file, "chat_voices", "m4a");

      // Send voice message
      await _chatService.sendVoiceMessage(
        receiverId: widget.receiverId,
        voiceUrl: downloadUrl,
        duration: duration,
        selfDestructDuration: _selfDestructDuration,
      );

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Voice note send failed: $e")),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onMessageLongPress(MessageModel msg) {
    final bool isMyMessage = msg.senderId == _currentUser.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? WAColors.appBarDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Emoji reactions bar overlay at top of bottomsheet
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ["👍", "❤️", "😂", "😮", "😢", "🙏"].map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        _chatService.updateReaction(
                          _getChatId(),
                          msg.id,
                          _currentUser.uid,
                          emoji,
                        );
                        Navigator.pop(context);
                      },
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1),
              
              // Reply Option
              ListTile(
                leading: const Icon(Icons.reply, color: WAColors.primary),
                title: const Text("Reply"),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyMessage = msg;
                  });
                },
              ),

              // Copy text option
              if (!msg.deleted && msg.messageType == 'text')
                ListTile(
                  leading: const Icon(Icons.copy, color: WAColors.primary),
                  title: const Text("Copy Text"),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: msg.message));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Text copied to clipboard")),
                    );
                  },
                ),

              // Remove reaction option
              if (msg.reactions.containsKey(_currentUser.uid))
                ListTile(
                  leading: const Icon(Icons.star_border, color: Colors.grey),
                  title: const Text("Remove Reaction"),
                  onTap: () {
                    _chatService.updateReaction(
                      _getChatId(),
                      msg.id,
                      _currentUser.uid,
                      null,
                    );
                    Navigator.pop(context);
                  },
                ),

              // Delete Options
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text("Delete message", style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmDialog(msg, isMyMessage);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmDialog(MessageModel msg, bool isMyMessage) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Message?"),
          content: const Text("Are you sure you want to delete this message?"),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text("Delete for Me", style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                _chatService.deleteMessage(_getChatId(), msg.id, false);
                Navigator.pop(context);
              },
            ),
            if (isMyMessage && !msg.deleted)
              TextButton(
                child: const Text("Delete for Everyone", style: TextStyle(color: Colors.redAccent)),
                onPressed: () {
                  _chatService.deleteMessage(_getChatId(), msg.id, true);
                  Navigator.pop(context);
                },
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatId = _getChatId();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? WAColors.backgroundDark : WAColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? WAColors.backgroundDark : WAColors.backgroundLight,
        elevation: 0,
        titleSpacing: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_rounded, color: WAColors.primary, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoodleScreen(chatId: chatId),
                ),
              );
            },
            tooltip: "Doodle Together",
          ),
          IconButton(
            icon: const Icon(Icons.favorite_rounded, color: Colors.pink, size: 24),
            onPressed: _sendNudge,
            tooltip: "Nudge Partner",
          ),
          const SizedBox(width: 8),
        ],
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection("users").doc(widget.receiverId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Text(widget.receiverName, style: TextStyle(color: isDark ? Colors.white : Colors.black87));
            }

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final String status = data["status"] ?? "offline";
            final String photoUrl = data["photoUrl"] ?? "";
            final String? mood = data["mood"] as String?;
            
            Timestamp? lastActiveTs = data["lastActive"] as Timestamp?;
            String presenceSubtitle = "offline";
            if (status == "online") {
              presenceSubtitle = "online";
            } else if (lastActiveTs != null) {
              final lastSeen = lastActiveTs.toDate();
              presenceSubtitle = "last seen at ${DateFormat('h:mm a').format(lastSeen)}";
            }

            final String moodSuffix = (mood != null && mood.isNotEmpty) ? " • ${mood}" : "";

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection("chats").doc(chatId).snapshots(),
              builder: (context, chatSnapshot) {
                if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                  final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                  final typingMap = chatData["typing"] as Map<String, dynamic>? ?? {};
                  final bool isTyping = typingMap[widget.receiverId] == true;
                  if (isTyping) {
                    presenceSubtitle = "typing...";
                  } else {
                    presenceSubtitle += moodSuffix;
                  }
                } else if (moodSuffix.isNotEmpty) {
                  presenceSubtitle += moodSuffix;
                }

                return Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: presenceSubtitle == "typing..." || status == "online" 
                              ? WAColors.primary.withOpacity(0.4) 
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.all(1),
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(
                                widget.receiverName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: WAColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.receiverName,
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            presenceSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: presenceSubtitle == "typing..." || presenceSubtitle == "online"
                                  ? WAColors.primary
                                  : Colors.grey.shade500,
                              fontWeight: presenceSubtitle == "typing..." || presenceSubtitle == "online"
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
      body: Stack(
        children: [
          // Custom Dynamic Wallpaper Backdrop
          Positioned.fill(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection("users").doc(_currentUser.uid).snapshots(),
              builder: (context, userSnapshot) {
                String? wallpaperUrl;
                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final data = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  wallpaperUrl = data["chatWallpaper"] as String?;
                }

                if (wallpaperUrl != null && wallpaperUrl.isNotEmpty) {
                  return CachedNetworkImage(
                    imageUrl: wallpaperUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => WAConstants.chatWallpaper(context, isDark: isDark),
                    errorWidget: (context, url, error) => WAConstants.chatWallpaper(context, isDark: isDark),
                  );
                }

                return WAConstants.chatWallpaper(context, isDark: isDark);
              },
            ),
          ),

          // Main Messaging Content Area
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("chats")
                      .doc(chatId)
                      .collection("messages")
                      .orderBy("timestamp")
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text(snapshot.error.toString()));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: WAColors.primary));
                    }

                    final messages = snapshot.data?.docs ?? [];
                    
                    // Auto-delete expired disappearing messages
                    final now = DateTime.now();
                    for (var doc in messages) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final selfDestruct = data["selfDestructDuration"] as int?;
                      final seen = data["seen"] as bool? ?? false;
                      final readTime = (data["readTime"] as Timestamp?)?.toDate();

                      if (selfDestruct != null && seen && readTime != null) {
                        final expiry = readTime.add(Duration(seconds: selfDestruct));
                        if (now.isAfter(expiry)) {
                          doc.reference.delete();
                        }
                      }
                    }
                    
                    // Mark read real-time
                    _markMessagesAsSeen();
                    
                    // Scroll down on changes
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(top: 10, bottom: 20),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = MessageModel.fromFirestore(messages[index]);
                        final bool isMe = msg.senderId == _currentUser.uid;

                        return MessageBubble(
                          message: msg,
                          isMe: isMe,
                          receiverName: widget.receiverName,
                          onReplySwipe: (replyMsg) {
                            setState(() {
                              _replyMessage = replyMsg;
                            });
                          },
                          onLongPress: _onMessageLongPress,
                          onDoubleTap: (doubleTapMsg) {
                            _chatService.updateReaction(
                              chatId,
                              doubleTapMsg.id,
                              _currentUser.uid,
                              "❤️",
                            );
                            HapticFeedback.mediumImpact();
                          },
                        );
                      },
                    );
                  },
                ),
              ),

              // Custom Input Area
              ChatInput(
                replyMessage: _replyMessage,
                onSendMessage: _handleSendMessage,
                onPickImage: _handlePickMedia,
                onCancelReply: () {
                  setState(() {
                    _replyMessage = null;
                  });
                },
                onTypingChanged: _handleTypingState,
                selfDestructDuration: _selfDestructDuration,
                onSelfDestructDurationChanged: (duration) {
                  setState(() {
                    _selfDestructDuration = duration;
                  });
                },
                onSendVoiceNote: _handleSendVoiceNote,
              ),
            ],
          ),
        ],
      ),
    );
  }
}