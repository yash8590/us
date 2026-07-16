import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'passcode_screen.dart';
import '../../app.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../utils/colors.dart';
import '../login/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final ChatService _chatService = ChatService();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  bool _isEditingName = false;
  bool _isEditingAbout = false;
  bool _isLoading = false;

  User? get _currentUser => _authService.currentUser;

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 50,
        maxWidth: 400,
      );

      if (pickedFile != null) {
        setState(() {
          _isLoading = true;
        });

        // Upload to Storage
        final imageUrl = await _chatService.uploadImage(
          File(pickedFile.path),
          "profile_pics",
        );

        // Save URL to user doc
        await FirebaseFirestore.instance
            .collection("users")
            .doc(_currentUser!.uid)
            .update({"photoUrl": imageUrl});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed. Ensure Firebase Storage is enabled. Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateName() async {
    final text = _nameController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(_currentUser!.uid)
        .update({"name": text});

    setState(() {
      _isEditingName = false;
    });
  }

  Future<void> _updateAbout() async {
    final text = _aboutController.text.trim();
    if (text.isEmpty) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(_currentUser!.uid)
        .update({"about": text});

    setState(() {
      _isEditingAbout = false;
    });
  }

  Future<void> _pickChatWallpaper() async {
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
                title: const Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _uploadAndSaveWallpaper();
                },
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded, color: Colors.redAccent),
                title: const Text("Reset to Default", style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.pop(context);
                  setState(() {
                    _isLoading = true;
                  });
                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(_currentUser!.uid)
                      .update({"chatWallpaper": FieldValue.delete()});
                  setState(() {
                    _isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Wallpaper reset to default")),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadAndSaveWallpaper() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
      );

      if (pickedFile != null) {
        setState(() {
          _isLoading = true;
        });

        // Upload to Storage (folder: "wallpapers")
        final imageUrl = await _chatService.uploadFile(
          File(pickedFile.path),
          "wallpapers",
          "jpg",
        );

        // Save URL to user doc in Firestore
        await FirebaseFirestore.instance
            .collection("users")
            .doc(_currentUser!.uid)
            .update({"chatWallpaper": imageUrl});

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Chat wallpaper updated successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Upload failed. Ensure Firebase Storage is enabled. Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMood(String? currentMood) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final moods = [
      "Happy 😊",
      "Busy 🕒",
      "Tired 😴",
      "Thinking of you 💖",
      "Missing you 🥺",
      "Excited 🎉",
      "Relaxed 🍃",
      "Sad 😢",
    ];

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Set Your Current Mood",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: moods.length,
                  itemBuilder: (context, index) {
                    final mood = moods[index];
                    final isSelected = mood == currentMood;

                    return ListTile(
                      title: Text(mood),
                      trailing: isSelected ? const Icon(Icons.check, color: Colors.green) : null,
                      onTap: () async {
                        Navigator.pop(context);
                        await FirebaseFirestore.instance
                            .collection("users")
                            .doc(_currentUser!.uid)
                            .update({"mood": mood});
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Mood updated to: $mood")),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _managePasscode() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPin = prefs.getString("app_passcode") != null;

    if (!mounted) return;

    if (hasPin) {
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
                  leading: const Icon(Icons.lock_open_rounded, color: Colors.redAccent),
                  title: const Text("Disable Passcode Lock", style: TextStyle(color: Colors.redAccent)),
                  onTap: () async {
                    Navigator.pop(context);
                    await prefs.remove("app_passcode");
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Passcode lock disabled")),
                    );
                  },
                ),
              ],
            ),
          );
        },
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PasscodeScreen(
            isSetupMode: true,
            onSuccess: () {
              Navigator.pop(context); // Back to settings
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Passcode set successfully!")),
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("users")
          .doc(_currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: WAColors.primary));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data["name"] ?? "User";
        final about = data["about"] ?? "Hey there! I am using UsChat.";
        final photoUrl = data["photoUrl"] ?? "";

        // Prepopulate text controllers if not editing
        if (!_isEditingName) {
          _nameController.text = name;
        }
        if (!_isEditingAbout) {
          _aboutController.text = about;
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 24),
              // Profile Photo Card
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 65,
                      backgroundColor: isDark ? const Color(0xFF202C33) : Colors.grey.shade300,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: WAColors.primary,
                              ),
                            )
                          : null,
                    ),
                    if (_isLoading)
                      const Positioned.fill(
                        child: CircleAvatar(
                          radius: 65,
                          backgroundColor: Colors.black45,
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: WAColors.primary,
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          onPressed: _pickProfileImage,
                        ),
                      ),
                    )
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Name Field
              ListTile(
                leading: const Icon(Icons.person, color: WAColors.primary),
                title: const Text(
                  "Name",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                subtitle: _isEditingName
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              autofocus: true,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: _updateName,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _isEditingName = false;
                              });
                            },
                          ),
                        ],
                      )
                    : Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                trailing: !_isEditingName
                    ? IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: WAColors.primary),
                        onPressed: () {
                          setState(() {
                            _isEditingName = true;
                          });
                        },
                      )
                    : null,
              ),

              const Divider(indent: 70),

              // Bio Field ("About")
              ListTile(
                leading: const Icon(Icons.info_outline, color: WAColors.primary),
                title: const Text(
                  "About",
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                subtitle: _isEditingAbout
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _aboutController,
                              autofocus: true,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: _updateAbout,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _isEditingAbout = false;
                              });
                            },
                          ),
                        ],
                      )
                    : Text(
                        about,
                        style: TextStyle(
                          fontSize: 15,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                trailing: !_isEditingAbout
                    ? IconButton(
                        icon: const Icon(Icons.edit, size: 18, color: WAColors.primary),
                        onPressed: () {
                          setState(() {
                            _isEditingAbout = true;
                          });
                        },
                      )
                    : null,
              ),

              const Divider(indent: 70),

              // Daily Mood Settings
              ListTile(
                leading: const Icon(Icons.sentiment_satisfied_alt_rounded, color: WAColors.primary),
                title: const Text("My Current Mood"),
                subtitle: Text(
                  data["mood"] != null ? "Feeling ${data["mood"]}" : "Share how you are feeling today...",
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.edit_rounded, size: 18, color: WAColors.primary),
                onTap: () => _updateMood(data["mood"] as String?),
              ),

              const Divider(indent: 70),

              // Theme Settings
              ListTile(
                leading: const Icon(Icons.brightness_6, color: WAColors.primary),
                title: const Text("Theme Mode"),
                subtitle: Text(
                  isDark ? "Dark Mode" : "Light Mode",
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: PopupMenuButton<ThemeMode>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (mode) {
                    UsApp.of(context).changeTheme(mode);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: ThemeMode.light,
                      child: Text("Light Mode"),
                    ),
                    const PopupMenuItem(
                      value: ThemeMode.dark,
                      child: Text("Dark Mode"),
                    ),
                    const PopupMenuItem(
                      value: ThemeMode.system,
                      child: Text("System Default"),
                    ),
                  ],
                ),
              ),

              const Divider(indent: 70),

              // Passcode Settings
              ListTile(
                leading: const Icon(Icons.lock_outline_rounded, color: WAColors.primary),
                title: const Text("App Passcode Lock"),
                subtitle: FutureBuilder<bool>(
                  future: SharedPreferences.getInstance().then((p) => p.getString("app_passcode") != null),
                  builder: (context, snapshot) {
                    final hasPin = snapshot.data ?? false;
                    return Text(
                      hasPin ? "Passcode is enabled" : "Secure your chats with a PIN",
                      style: const TextStyle(fontSize: 13),
                    );
                  },
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white70 : Colors.black54),
                onTap: _managePasscode,
              ),

              const Divider(indent: 70),

              // Chat Wallpaper Settings
              ListTile(
                leading: const Icon(Icons.wallpaper_rounded, color: WAColors.primary),
                title: const Text("Chat Wallpaper"),
                subtitle: const Text(
                  "Choose a custom chat background image",
                  style: TextStyle(fontSize: 13),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white70 : Colors.black54),
                onTap: _pickChatWallpaper,
              ),

              const Divider(indent: 70),

              // Logout Button
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                onTap: () async {
                  await _authService.logout();
                  if (!context.mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
