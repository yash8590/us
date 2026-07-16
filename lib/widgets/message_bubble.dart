import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import '../models/message_model.dart';
import '../utils/colors.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final Function(MessageModel)? onReplySwipe;
  final Function(MessageModel)? onLongPress;
  final Function(MessageModel)? onDoubleTap;
  final String receiverName;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.onReplySwipe,
    this.onLongPress,
    this.onDoubleTap,
    required this.receiverName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textStyle = TextStyle(
      fontSize: 15,
      height: 1.3,
      color: message.deleted
          ? (isMe ? Colors.white60 : Colors.grey.shade500)
          : (isMe
              ? Colors.white
              : (isDark ? WAColors.textPrimaryDark : Colors.black87)),
      fontStyle: message.deleted ? FontStyle.italic : FontStyle.normal,
    );

    return GestureDetector(
      onLongPress: onLongPress != null ? () => onLongPress!(message) : null,
      onDoubleTap: onDoubleTap != null ? () => onDoubleTap!(message) : null,
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
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Bubble Card
              Container(
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF4F46E5), const Color(0xFF3730A3)]
                              : [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isMe
                      ? null
                      : (isDark ? WAColors.receiverBubbleDark : WAColors.receiverBubbleLight),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 20),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.15 : 0.03),
                      offset: const Offset(0, 3),
                      blurRadius: 6,
                    )
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Reply header if replying to another message
                    if (message.replyTo != null && !message.deleted) ...[
                      _buildReplyHeader(context, isDark),
                      const SizedBox(height: 8),
                    ],

                    // Image display
                    if (message.messageType == 'image' && message.mediaUrl != null && !message.deleted) ...[
                      GestureDetector(
                        onTap: () => _viewFullScreenImage(context),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
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
                              child: const Center(child: Icon(Icons.error_outline_rounded, color: Colors.red)),
                            ),
                            fit: BoxFit.cover,
                            height: 200,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Video display
                    if (message.messageType == 'video' && message.mediaUrl != null && !message.deleted) ...[
                      InlineVideoPlayer(videoUrl: message.mediaUrl!),
                      const SizedBox(height: 8),
                    ],

                    // Voice Note display
                    if (message.messageType == 'voice' && message.mediaUrl != null && !message.deleted) ...[
                      VoiceNotePlayer(
                        audioUrl: message.mediaUrl!,
                        duration: message.duration ?? 0,
                        isMe: isMe,
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Message text
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 54, bottom: 2),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (message.deleted) ...[
                                  Icon(Icons.block_flipped, size: 14, color: isMe ? Colors.white60 : Colors.grey),
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
                bottom: 6,
                right: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.selfDestructDuration != null) ...[
                      if (!message.seen)
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: isMe ? Colors.white.withOpacity(0.7) : (isDark ? Colors.white38 : Colors.black38),
                        )
                      else if (message.readTime != null)
                        DisappearingTimerWidget(
                          readTime: message.readTime!,
                          duration: message.selfDestructDuration!,
                          color: isMe ? Colors.white.withOpacity(0.7) : WAColors.primary,
                        ),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      DateFormat('hh:mm a').format(message.timestamp),
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isMe
                            ? Colors.white.withOpacity(0.7)
                            : (isDark ? WAColors.textSecondaryDark : WAColors.textSecondaryLight),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.done_all_rounded,
                        size: 14,
                        color: message.seen ? const Color(0xFF34D399) : Colors.white.withOpacity(0.5),
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

class InlineVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const InlineVideoPlayer({super.key, required this.videoUrl});

  @override
  State<InlineVideoPlayer> createState() => _InlineVideoPlayerState();
}

class _InlineVideoPlayerState extends State<InlineVideoPlayer> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _initialized = true;
          });
        }
      }).catchError((err) {
        if (mounted) {
          setState(() {
            _error = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Icon(Icons.error_outline_rounded, color: Colors.redAccent),
        ),
      );
    }

    if (!_initialized) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: WAColors.primary),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            },
            child: CircleAvatar(
              radius: 26,
              backgroundColor: Colors.black.withOpacity(0.5),
              child: Icon(
                _controller.value.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VoiceNotePlayer extends StatefulWidget {
  final String audioUrl;
  final int duration;
  final bool isMe;

  const VoiceNotePlayer({
    super.key,
    required this.audioUrl,
    required this.duration,
    required this.isMe,
  });

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _compSub;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _duration = Duration(seconds: widget.duration);

    _posSub = _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _durSub = _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _stateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });

    _compSub = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _compSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      print("Audio playback error: $e");
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString();
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final playerColor = widget.isMe ? Colors.white : WAColors.primary;
    final progressColor = widget.isMe ? Colors.white30 : Colors.black12;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlayback,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: playerColor.withOpacity(0.15),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: playerColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                WaveformSeeker(
                  position: _position,
                  duration: _duration,
                  activeColor: playerColor,
                  inactiveColor: progressColor,
                  onSeek: (percentage) {
                    final seekMs = (_duration.inMilliseconds * percentage).toInt();
                    _audioPlayer.seek(Duration(milliseconds: seekMs));
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: widget.isMe ? Colors.white70 : Colors.grey.shade600, fontSize: 10),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: TextStyle(color: widget.isMe ? Colors.white70 : Colors.grey.shade600, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class DisappearingTimerWidget extends StatefulWidget {
  final DateTime readTime;
  final int duration;
  final Color color;

  const DisappearingTimerWidget({
    super.key,
    required this.readTime,
    required this.duration,
    required this.color,
  });

  @override
  State<DisappearingTimerWidget> createState() => _DisappearingTimerWidgetState();
}

class _DisappearingTimerWidgetState extends State<DisappearingTimerWidget> {
  Timer? _timer;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _calculateSecondsLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateSecondsLeft();
    });
  }

  void _calculateSecondsLeft() {
    final expiry = widget.readTime.add(Duration(seconds: widget.duration));
    final diff = expiry.difference(DateTime.now()).inSeconds;
    if (mounted) {
      setState(() {
        _secondsLeft = diff < 0 ? 0 : diff;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_secondsLeft <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, color: widget.color, size: 13),
        const SizedBox(width: 2),
        Text(
          "${_secondsLeft}s",
          style: TextStyle(color: widget.color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class WaveformSeeker extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final Color activeColor;
  final Color inactiveColor;
  final Function(double) onSeek;

  const WaveformSeeker({
    super.key,
    required this.position,
    required this.duration,
    required this.activeColor,
    required this.inactiveColor,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final totalBars = 20;
    final List<double> heights = [8, 14, 6, 20, 12, 24, 10, 16, 12, 22, 8, 14, 10, 18, 6, 16, 10, 16, 12, 24];

    final double progress = duration.inMilliseconds > 0 
        ? position.inMilliseconds / duration.inMilliseconds 
        : 0.0;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final dx = details.localPosition.dx;
          final percentage = (dx / box.size.width).clamp(0.0, 1.0);
          onSeek(percentage);
        }
      },
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          final dx = details.localPosition.dx;
          final percentage = (dx / box.size.width).clamp(0.0, 1.0);
          onSeek(percentage);
        }
      },
      child: Container(
        height: 28,
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(totalBars, (index) {
            final isPlayed = (index / totalBars) <= progress;
            final height = heights[index % heights.length];

            return Container(
              width: 2.5,
              height: height,
              decoration: BoxDecoration(
                color: isPlayed ? activeColor : inactiveColor,
                borderRadius: BorderRadius.circular(1.2),
              ),
            );
          }),
        ),
      ),
    );
  }
}
