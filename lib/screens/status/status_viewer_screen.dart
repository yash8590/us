import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/status_model.dart';
import '../../services/chat_service.dart';
import '../../utils/colors.dart';

class StatusViewerScreen extends StatefulWidget {
  final UserStatus userStatus;

  const StatusViewerScreen({super.key, required this.userStatus});

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animController;
  int _currentIndex = 0;
  
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(vsync: this);

    final firstItem = widget.userStatus.items.first;
    _showStory(item: firstItem);

    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _animController.stop();
      } else {
        _animController.forward();
      }
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animController.stop();
        _animController.reset();
        setState(() {
          if (_currentIndex + 1 < widget.userStatus.items.length) {
            _currentIndex++;
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
            _showStory(item: widget.userStatus.items[_currentIndex]);
          } else {
            // End of stories, return
            Navigator.pop(context);
          }
        });
      }
    });
  }

  void _showStory({required StatusItem item}) {
    _animController.stop();
    _animController.reset();
    // Stories run for 5 seconds
    _animController.duration = const Duration(seconds: 5);
    _animController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _replyController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    // If the reply bar has focus, let clicks dismiss focus first instead of navigating
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      return;
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    final double dx = details.globalPosition.dx;

    // Pause on tap
    _animController.stop();

    if (dx < screenWidth / 3) {
      // Tap Left: Go backward
      setState(() {
        if (_currentIndex > 0) {
          _currentIndex--;
          _pageController.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _showStory(item: widget.userStatus.items[_currentIndex]);
        }
      });
    } else {
      // Tap Right: Go forward
      setState(() {
        if (_currentIndex + 1 < widget.userStatus.items.length) {
          _currentIndex++;
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _showStory(item: widget.userStatus.items[_currentIndex]);
        } else {
          // Last page, exit viewer
          Navigator.pop(context);
        }
      });
    }
  }

  void _onLongPress() {
    if (!_focusNode.hasFocus) {
      _animController.stop();
    }
  }

  void _onLongPressUp() {
    if (!_focusNode.hasFocus) {
      _animController.forward();
    }
  }

  Future<void> _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    _focusNode.unfocus();

    try {
      final chatService = ChatService();
      await chatService.sendMessage(
        receiverId: widget.userStatus.uid,
        message: "💬 Reply to status: $text",
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Reply sent to chat!"), 
            duration: Duration(milliseconds: 1500),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to send reply: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusItems = widget.userStatus.items;
    final currentStatus = statusItems[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPress: _onLongPress,
        onLongPressUp: _onLongPressUp,
        child: Stack(
          children: [
            // Page view displaying statuses
            PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: statusItems.length,
              itemBuilder: (context, index) {
                final item = statusItems[index];

                if (item.mediaUrl != null) {
                  // Render Image Status
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: item.mediaUrl!,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                      if (item.caption != null && item.caption!.isNotEmpty)
                        Positioned(
                          bottom: 120, // push up to clear input box
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              item.caption!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                } else {
                  // Render Text Status
                  return Container(
                    color: Color(item.backgroundColor),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32.0, 32.0, 32.0, 100.0),
                        child: Text(
                          item.text ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }
              },
            ),

            // Top Status Bars and User Details
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: Column(
                children: [
                  // Progress bars indicator
                  Row(
                    children: statusItems.asMap().entries.map((entry) {
                      final idx = entry.key;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Stack(
                            children: [
                              Container(
                                height: 3,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              if (idx <= _currentIndex)
                                AnimatedBuilder(
                                  animation: _animController,
                                  builder: (context, child) {
                                    final val = idx < _currentIndex
                                        ? 1.0
                                        : _animController.value;
                                    return FractionallySizedBox(
                                      widthFactor: val,
                                      child: Container(
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  // User Details Header
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: WAColors.primary.withOpacity(0.8),
                        backgroundImage: widget.userStatus.userPhotoUrl != null &&
                                widget.userStatus.userPhotoUrl!.isNotEmpty
                            ? NetworkImage(widget.userStatus.userPhotoUrl!)
                            : null,
                        child: widget.userStatus.userPhotoUrl == null ||
                                widget.userStatus.userPhotoUrl!.isEmpty
                            ? Text(
                                widget.userStatus.userName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.userStatus.userName,
                              style: const TextStyle(
                                color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                DateFormat('hh:mm a').format(currentStatus.timestamp),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Quick Reply Box
              Positioned(
                bottom: 16,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: GestureDetector(
                    onTap: () {}, // Absorb taps so it doesn't trigger story navigation
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                            ),
                            child: Center(
                              child: TextField(
                                controller: _replyController,
                                focusNode: _focusNode,
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: "Send a reply to ${widget.userStatus.userName}...",
                                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _sendReply,
                          child: Container(
                            height: 46,
                            width: 46,
                            decoration: const BoxDecoration(
                              color: WAColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
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
