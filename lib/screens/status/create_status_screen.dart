import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/chat_service.dart';
import '../../utils/constants.dart';
import '../../widgets/loading_widget.dart';

class CreateStatusScreen extends StatefulWidget {
  const CreateStatusScreen({super.key});

  @override
  State<CreateStatusScreen> createState() => _CreateStatusScreenState();
}

class _CreateStatusScreenState extends State<CreateStatusScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();
  
  File? _selectedImage;
  int _bgIndex = 0;
  bool _isLoading = false;

  void _cycleBackgroundColor() {
    setState(() {
      _bgIndex = (_bgIndex + 1) % WAConstants.statusBackgrounds.length;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1080,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: $e")),
      );
    }
  }

  Future<void> _postStatus() async {
    final textContent = _textController.text.trim();
    
    if (_selectedImage == null && textContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please write a message or select an image")),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      if (_selectedImage != null) {
        // Upload image to firebase storage
        imageUrl = await _chatService.uploadImage(_selectedImage!, "status_media");
      }

      await _chatService.uploadStatus(
        text: imageUrl == null ? textContent : null,
        mediaUrl: imageUrl,
        backgroundColor: WAConstants.statusBackgrounds[_bgIndex].value,
        caption: imageUrl != null ? _captionController.text.trim() : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Status uploaded successfully!")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Status upload failed. Ensure Firebase Storage is active. Error: $e")),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: WALoadingWidget(message: "Uploading status..."),
      );
    }

    if (_selectedImage != null) {
      // Build Image Status composer
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text("Compose Image Status"),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _postStatus,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: Image.file(_selectedImage!, fit: BoxFit.contain),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black54,
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Add a caption...",
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.teal,
                      onPressed: _postStatus,
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Build Text Status composer
    final activeBg = WAConstants.statusBackgrounds[_bgIndex];
    return Scaffold(
      backgroundColor: activeBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.palette),
            onPressed: _cycleBackgroundColor,
          ),
          IconButton(
            icon: const Icon(Icons.image),
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt),
            onPressed: () => _pickImage(ImageSource.camera),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: TextField(
                controller: _textController,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  hintText: "Type a status",
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: _postStatus,
              child: Icon(Icons.send, color: activeBg),
            ),
          ),
        ],
      ),
    );
  }
}
