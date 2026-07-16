import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/message_model.dart';
import '../utils/colors.dart';

class ChatInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final Function() onPickImage;
  final MessageModel? replyMessage;
  final Function() onCancelReply;
  final Function(bool) onTypingChanged;
  final int? selfDestructDuration;
  final Function(int?) onSelfDestructDurationChanged;
  final Function(File voiceFile, int duration) onSendVoiceNote;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    required this.onPickImage,
    this.replyMessage,
    required this.onCancelReply,
    required this.onTypingChanged,
    required this.selfDestructDuration,
    required this.onSelfDestructDurationChanged,
    required this.onSendVoiceNote,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  bool _showSendButton = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  // Recording variables
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  int _recordingDuration = 0;
  Timer? _recordingTimer;
  String? _localPath;

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
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
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

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a";
        _localPath = path;

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          setState(() {
            _recordingDuration++;
          });
        });
      }
    } catch (e) {
      print("Error starting recording: $e");
    }
  }

  Future<void> _stopAndSendRecording() async {
    try {
      _recordingTimer?.cancel();
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          widget.onSendVoiceNote(file, _recordingDuration);
        }
      }
    } catch (e) {
      print("Error stopping recording: $e");
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _recordingTimer?.cancel();
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });
      if (_localPath != null) {
        final file = File(_localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      print("Error cancelling recording: $e");
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
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF151B2C) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                )
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.reply_rounded, color: WAColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
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
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  onPressed: widget.onCancelReply,
                ),
              ],
            ),
          ),

        // Input and Send bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Row(
              children: [
                // Rounded Chat input box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF151B2C) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Row(
                      children: _isRecording
                          ? [
                              const SizedBox(width: 16),
                              const Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 14),
                              const SizedBox(width: 8),
                              const VoiceWaveformWidget(color: Colors.redAccent, isAnimated: true),
                              const SizedBox(width: 10),
                              Text(
                                "Recording ${_recordingDuration ~/ 60}:${(_recordingDuration % 60).toString().padLeft(2, '0')}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                onPressed: _cancelRecording,
                              ),
                              const SizedBox(width: 4),
                            ]
                          : [
                              // Attachment Button (Image Picker trigger)
                              IconButton(
                                icon: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                                onPressed: widget.onPickImage,
                              ),
                              
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  maxLines: 5,
                                  minLines: 1,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : Colors.black87,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "Type a message",
                                    hintStyle: TextStyle(
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                                      fontSize: 15,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  ),
                                ),
                              ),

                              // Timer Button (Disappearing Messages)
                              _buildTimerToggle(context),

                              // Smiley Button
                              IconButton(
                                icon: Icon(
                                  Icons.emoji_emotions_outlined,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                                onPressed: () {},
                              ),
                            ],
                    ),
                  ),
                ),
                
                const SizedBox(width: 10),

                // Trailing circular Send / Mic Button
                GestureDetector(
                  onTap: _isRecording
                      ? _stopAndSendRecording
                      : (_showSendButton ? _send : _startRecording),
                  child: Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: _isRecording ? Colors.redAccent : WAColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isRecording ? Colors.redAccent : WAColors.primary).withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isRecording
                          ? Icons.send_rounded
                          : (_showSendButton ? Icons.send_rounded : Icons.mic_rounded),
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

  Widget _buildTimerToggle(BuildContext context) {
    IconData icon = Icons.timer_off_outlined;
    Color color = Colors.grey;
    String label = "";

    if (widget.selfDestructDuration == 10) {
      icon = Icons.timer_outlined;
      color = WAColors.primary;
      label = "10s";
    } else if (widget.selfDestructDuration == 60) {
      icon = Icons.timer_outlined;
      color = WAColors.primary;
      label = "1m";
    } else if (widget.selfDestructDuration == 3600) {
      icon = Icons.timer_outlined;
      color = WAColors.primary;
      label = "1h";
    }

    return GestureDetector(
      onTap: _cycleSelfDestructDuration,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: widget.selfDestructDuration != null
              ? WAColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _cycleSelfDestructDuration() {
    int? next;
    if (widget.selfDestructDuration == null) {
      next = 10;
    } else if (widget.selfDestructDuration == 10) {
      next = 60;
    } else if (widget.selfDestructDuration == 60) {
      next = 3600;
    } else {
      next = null;
    }
    widget.onSelfDestructDurationChanged(next);
  }
}

class VoiceWaveformWidget extends StatefulWidget {
  final Color color;
  final bool isAnimated;

  const VoiceWaveformWidget({
    super.key,
    required this.color,
    required this.isAnimated,
  });

  @override
  State<VoiceWaveformWidget> createState() => _VoiceWaveformWidgetState();
}

class _VoiceWaveformWidgetState extends State<VoiceWaveformWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<int> _heightMultiplier = [8, 18, 10, 24, 12, 16, 6, 20, 14, 10, 22, 8, 16, 12, 10];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.isAnimated) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant VoiceWaveformWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated && !_animController.isAnimating) {
      _animController.repeat(reverse: true);
    } else if (!widget.isAnimated && _animController.isAnimating) {
      _animController.stop();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_heightMultiplier.length, (index) {
            final multiplier = _heightMultiplier[index];
            final value = widget.isAnimated ? _animController.value : 0.4;
            final height = (multiplier * (0.3 + 0.7 * value)).clamp(3.0, 26.0);

            return Container(
              width: 2.5,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1.0),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.85),
                borderRadius: BorderRadius.circular(1.2),
              ),
            );
          }),
        );
      },
    );
  }
}
