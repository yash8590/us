import 'dart:async';
import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../utils/colors.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function() onPickImage;
  final MessageModel? replyMessage;
  final Function() onCancelReply;
  final Function(bool) onTypingChanged;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onPickImage,
    this.replyMessage,
    required this.onCancelReply,
    required this.onTypingChanged,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _showSendButton = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _controller.text.trim();
    final hasText = text.isNotEmpty;

    // Show/hide send button dynamically
    if (hasText != _showSendButton) {
      setState(() {
        _showSendButton = hasText;
      });
    }

    // Typing presence logic
    if (hasText) {
      if (!_isTyping) {
        _isTyping = true;
        widget.onTypingChanged(true);
      }
      
      // Reset timer to clear typing state after inactivity
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTyping) {
          _isTyping = false;
          widget.onTypingChanged(false);
        }
      });
    } else {
      if (_isTyping) {
        _isTyping = false;
        widget.onTypingChanged(false);
        _typingTimer?.cancel();
      }
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _controller.clear();
    
    // Stop typing state immediately on send
    if (_isTyping) {
      _isTyping = false;
      widget.onTypingChanged(false);
      _typingTimer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Quoted message reply preview banner
        if (widget.replyMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2C34) : Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.reply, color: WAColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Replying to Message",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: WAColors.primary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.replyMessage!.message,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.grey.shade400 : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                  onPressed: widget.onCancelReply,
                ),
              ],
            ),
          ),

        // Input and Send bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                // Rounded Chat input box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF202C33) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                        )
                      ],
                    ),
                    child: Row(
                      children: [
                        // Smiley Button (standard keyboard trigger here)
                        IconButton(
                          icon: Icon(
                            Icons.emoji_emotions_outlined,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          onPressed: () {
                            // Show system emoji keyboard / normal focus
                          },
                        ),
                        
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            maxLines: 5,
                            minLines: 1,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: "Type a message",
                              hintStyle: TextStyle(
                                color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),

                        // Image attachment button
                        IconButton(
                          icon: Icon(
                            Icons.camera_alt,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                          onPressed: widget.onPickImage,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 6),

                // Trailing circular Send / Record Button
                GestureDetector(
                  onTap: _showSendButton ? _send : widget.onPickImage,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: WAColors.primary,
                    child: Icon(
                      _showSendButton ? Icons.send : Icons.image,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
