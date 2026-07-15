import 'dart:io';
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

    final batch = FirebaseFirestore.instance.batch();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {"seen": true});
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
    );

    setState(() {
      _replyMessage = null;
    });
    _scrollToBottom();
  }

  Future<void> _handlePickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 800,
      );

      if (pickedFile != null) {
        final File file = File(pickedFile.path);

        // Show uploading feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Uploading image...")),
        );

        // Upload and send
        final imageUrl = await _chatService.uploadImage(file, "chat_images");

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

        await _chatService.sendImageMessage(
          receiverId: widget.receiverId,
          imageUrl: imageUrl,
          replyTo: replyData,
        );

        setState(() {
          _replyMessage = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Image send failed. Ensure Firebase Storage is enabled. Error: $e")),
      );
    }
  }

  void _handleTypingState(bool isTyping) {
    _chatService.setTypingState(_getChatId(), _currentUser.uid, isTyping);
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
      appBar: AppBar(
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection("users").doc(widget.receiverId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Text(widget.receiverName);
            }

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final String status = data["status"] ?? "offline";
            final String photoUrl = data["photoUrl"] ?? "";
            
            Timestamp? lastActiveTs = data["lastActive"] as Timestamp?;
            String presenceSubtitle = "offline";
            if (status == "online") {
              presenceSubtitle = "online";
            } else if (lastActiveTs != null) {
              final lastSeen = lastActiveTs.toDate();
              presenceSubtitle = "last seen at ${DateFormat('h:mm a').format(lastSeen)}";
            }

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection("chats").doc(chatId).snapshots(),
              builder: (context, chatSnapshot) {
                if (chatSnapshot.hasData && chatSnapshot.data!.exists) {
                  final chatData = chatSnapshot.data!.data() as Map<String, dynamic>;
                  final typingMap = chatData["typing"] as Map<String, dynamic>? ?? {};
                  final bool isTyping = typingMap[widget.receiverId] == true;
                  if (isTyping) {
                    presenceSubtitle = "typing...";
                  }
                }

                return Row(
                  children: [
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: isDark ? const Color(0xFF202C33) : Colors.grey.shade300,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              widget.receiverName[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.receiverName,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            presenceSubtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: presenceSubtitle == "typing..."
                                  ? (isDark ? WAColors.accentDark : Colors.white)
                                  : Colors.white70,
                              fontWeight: presenceSubtitle == "typing..."
                                  ? FontWeight.bold
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
          // Custom Classic Wallpaper Backdrop
          Positioned.fill(
            child: WAConstants.chatWallpaper(context, isDark: isDark),
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
                onPickImage: _handlePickImage,
                onCancelReply: () {
                  setState(() {
                    _replyMessage = null;
                  });
                },
                onTypingChanged: _handleTypingState,
              ),
            ],
          ),
        ],
      ),
    );
  }
}