import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../utils/colors.dart';
import '../chat/chat_screen.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key});

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: "Search name or email...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Select contact",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection("users").snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();
                      final count = snapshot.data!.docs.where((doc) => doc.id != _currentUser.uid).length;
                      return Text(
                        "$count contact${count == 1 ? '' : 's'}",
                        style: const TextStyle(fontSize: 12, color: Colors.white70),
                      );
                    },
                  )
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                _searchQuery = "";
                _searchController.clear();
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("users").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: WAColors.primary));
          }

          final users = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final isNotMe = data["uid"] != _currentUser.uid;
            
            if (_isSearching && _searchQuery.isNotEmpty) {
              final name = (data["name"] ?? "").toString().toLowerCase();
              final email = (data["email"] ?? "").toString().toLowerCase();
              return isNotMe && (name.contains(_searchQuery) || email.contains(_searchQuery));
            }
            return isNotMe;
          }).toList();

          if (users.isEmpty) {
            return const Center(child: Text("No contacts found"));
          }

          return ListView.builder(
            itemCount: users.length + 2, // Added top Mock rows for realism
            itemBuilder: (context, index) {
              if (index == 0) {
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: WAColors.primary,
                    child: Icon(Icons.group, color: Colors.white),
                  ),
                  title: const Text("New group", style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Groups feature coming soon!")),
                    );
                  },
                );
              }
              if (index == 1) {
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: WAColors.primary,
                    child: Icon(Icons.person_add, color: Colors.white),
                  ),
                  title: const Text("New contact", style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.qr_code, color: Colors.grey),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Add Contact via QR code coming soon!")),
                    );
                  },
                );
              }

              final userDoc = users[index - 2];
              final user = userDoc.data() as Map<String, dynamic>;
              final name = user["name"] ?? "User";
              final about = user["about"] ?? "Hey there! I am using UsChat.";
              final photoUrl = user["photoUrl"] ?? "";

              return ListTile(
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: isDark ? const Color(0xFF202C33) : Colors.grey.shade300,
                  backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          name[0].toUpperCase(),
                          style: const TextStyle(
                            color: WAColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                subtitle: Text(
                  about,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.grey),
                ),
                onTap: () {
                  // Direct navigation replacing the selection stack so going back goes to Home
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        receiverId: user["uid"],
                        receiverName: name,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
