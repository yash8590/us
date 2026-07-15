import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../utils/colors.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final Function(MessageModel)? onReplySwipe;
  final Function(MessageModel)? onLongPress;
  final String receiverName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReplySwipe,
    this.onLongPress,
    required this.receiverName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bubbleBg = isMe
        ? (isDark ? WAColors.senderBubbleDark : WAColors.senderBubbleLight)
        : (isDark ? WAColors.receiverBubbleDark : WAColors.receiverBubbleLight);

    final textStyle = TextStyle(
      fontSize: 16,
      color: message.deleted
          ? Colors.grey
          : (isMe
              ? (isDark ? WAColors.textPrimaryDark : Colors.black87)
              : (isDark ? WAColors.textPrimaryDark : Colors.black87)),
      fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
    );

    return GestureDetector(
      onLongPress: onLongPress != null ? () => onLongPress!(message) : null,
      onHorizontalDragEnd: onReplySwipe != null
          ? (details) {
              // Swipe right to reply
              if (details.primaryVelocity != null && details.primaryVelocity! > 100) {
                onReplySwipe!(message);
              }
            }
          : null,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bubble Card
              Container(
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(isMe ? 12 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      offset: const Offset(0, 1),
                      blurRadius: 1,
                    )
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply header if replying to another message
                    if (message.replyTo != null && !message.deleted) ...[
                      _buildReplyHeader(context, isDark),
                      const SizedBox(height: 6),
                    ],

                    // Image display
                    if (message.messageType == 'image' && message.mediaUrl != null && !message.deleted) ...[
                      GestureDetector(
                        onTap: () => _viewFullScreenImage(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: message.mediaUrl!,
                            placeholder: (context, url) => Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey.withOpacity(0.1),
                              child: const Center(
                                child: CircularProgressIndicator(color: WAColors.primary),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey.withOpacity(0.2),
                              child: const Center(child: Icon(Icons.error, color: Colors.red)),
                            ),
                            fit: BoxFit.cover,
                            height: 200,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],

                    // Message text
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 60, bottom: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.deleted) ...[
                                  const Icon(Icons.block, size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                ],
                                Flexible(
                                  child: Text(
                                    message.message,
                                    style: textStyle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Positioned timestamp + ticks at bottom-right corner of the bubble
              Positioned(
                bottom: 4,
                right: 8,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? WAColors.textSecondaryDark
                            : WAColors.textSecondaryLight,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all,
                        size: 15,
                        color: message.seen ? Colors.blue : Colors.grey,
                      ),
                    ],
                  ],
                ),
              ),

              // Floating Reactions Badge
              if (message.reactions.isNotEmpty && !message.deleted)
                Positioned(
                  bottom: -12,
                  right: isMe ? null : 10,
                  left: isMe ? 10 : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF233138) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        )
                      ],
                      border: Border.all(
                        color: isDark ? const Color(0xFF111B21) : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: message.reactions.values
                          .take(3)
                          .map(
                            (emoji) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyHeader(BuildContext context, bool isDark) {
    final senderName = message.replyTo!['senderName'] ?? '';
    final quotedMsg = message.replyTo!['message'] ?? '';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: isMe ? WAColors.primary : Colors.blue,
            width: 4,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isMe ? WAColors.primary : Colors.blue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quotedMsg,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _viewFullScreenImage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(receiverName),
          ),
          body: Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl!,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
