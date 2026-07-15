import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/status_model.dart';
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(vsync: this);

    final firstItem = widget.userStatus.items.first;
    _showStory(item: firstItem);

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
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
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
    // Pause animation
    _animController.stop();
  }

  void _onLongPressUp() {
    // Resume animation
    _animController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final statusItems = widget.userStatus.items;
    final currentStatus = statusItems[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
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
                          bottom: 48,
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
                        padding: const EdgeInsets.all(32.0),
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
          ],
        ),
      ),
    );
  }
}
