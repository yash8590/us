import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/status_model.dart';
import '../../services/chat_service.dart';
import '../../utils/colors.dart';
import '../chat/chat_screen.dart';
import '../status/create_status_screen.dart';
import '../status/status_viewer_screen.dart';
import '../settings/settings_screen.dart';
import 'select_contact_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChatService _chatService = ChatService();
  final User _currentUser = FirebaseAuth.instance.currentUser!;
  
  int _currentIndex = 0;
  bool _isSearching = false;
  String _searchQuery = "";

  final TextEditingController _searchController = TextEditingController();

  String _formatMessageTime(Timestamp? ts) {
    if (ts == null) return "";
    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date).inDays;

    if (diff == 0) {
      return DateFormat("h:mm a").format(date);
    } else if (diff == 1) {
      return "Yesterday";
    } else {
      return DateFormat("d/M/y").format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Widget> tabs = [
      _buildChatsTab(isDark),
      _buildUpdatesTab(isDark),
      const SettingsScreen(),
    ];

    final List<String> titles = [
      "UsChat",
      "Updates",
      "Settings",
    ];

    return Scaffold(
      appBar: AppBar(
        title: _isSearching && _currentIndex == 0
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: "Search chats...",
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              )
            : Text(
                titles[_currentIndex],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
              ),
        actions: [
          if (_currentIndex == 0)
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
      body: tabs[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: isDark ? WAColors.accentDark : WAColors.primary,
        unselectedItemColor: Colors.grey,
        backgroundColor: isDark ? WAColors.appBarDark : Colors.white,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            _isSearching = false;
            _searchQuery = "";
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat),
            label: "Chats",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline),
            activeIcon: Icon(Icons.star),
            label: "Updates",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              backgroundColor: WAColors.primary,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectContactScreen()),
                );
              },
              child: const Icon(Icons.chat, color: Colors.white),
            )
          : _currentIndex == 1
              ? FloatingActionButton(
                  backgroundColor: WAColors.primary,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateStatusScreen()),
                    );
                  },
                  child: const Icon(Icons.camera_alt, color: Colors.white),
                )
              : null,
    );
  }

  // Chats Tab View: Queries active threads and orders in-memory
  Widget _buildChatsTab(bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("chats")
          .where("participants", arrayContains: _currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text("Error loading chats: ${snapshot.error}"));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: WAColors.primary));
        }

        final chatDocs = snapshot.data!.docs;

        // In-memory sorting to avoid Firestore index build constraints
        chatDocs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)["lastMessageTime"] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)["lastMessageTime"] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        if (chatDocs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 85,
                    color: Colors.grey.withOpacity(0.4),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    "No chats yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Tap the chat button below to start a conversation.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, height: 1.3),
                  ),
                ],
              ),
            ),
          );
        }

        // Apply local search filtering
        final filteredChats = chatDocs.where((doc) {
          final chatData = doc.data() as Map<String, dynamic>;
          final participants = chatData["participants"] as List<dynamic>? ?? [];
          final otherUserId = participants.firstWhere((id) => id != _currentUser.uid, orElse: () => "");
          
          if (otherUserId.isEmpty) return false;

          if (_isSearching && _searchQuery.isNotEmpty) {
            final participantNames = chatData["participantNames"] as Map<String, dynamic>? ?? {};
            final otherUserName = (participantNames[otherUserId] ?? "").toString().toLowerCase();
            return otherUserName.contains(_searchQuery);
          }
          return true;
        }).toList();

        if (filteredChats.isEmpty) {
          return const Center(child: Text("No chats found matching search"));
        }

        return ListView.separated(
          itemCount: filteredChats.length,
          separatorBuilder: (context, index) => const Divider(height: 1, indent: 80),
          itemBuilder: (context, index) {
            final chatDoc = filteredChats[index];
            final chatData = chatDoc.data() as Map<String, dynamic>;
            final chatId = chatDoc.id;

            final participants = chatData["participants"] as List<dynamic>? ?? [];
            final otherUserId = participants.firstWhere((id) => id != _currentUser.uid, orElse: () => "");

            final lastMessage = chatData["lastMessage"] ?? "";
            final lastMessageTime = chatData["lastMessageTime"] as Timestamp?;
            final timeStr = _formatMessageTime(lastMessageTime);

            // Fetch actual live recipient details
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection("users").doc(otherUserId).snapshots(),
              builder: (context, userSnapshot) {
                String otherUserName = "User";
                String photoUrl = "";
                bool isOnline = false;

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  otherUserName = userData["name"] ?? "User";
                  photoUrl = userData["photoUrl"] ?? "";
                  isOnline = userData["status"] == "online";
                } else {
                  final participantNames = chatData["participantNames"] as Map<String, dynamic>? ?? {};
                  otherUserName = participantNames[otherUserId] ?? "User";
                }

                // Check unread count
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("chats")
                      .doc(chatId)
                      .collection("messages")
                      .where("receiverId", isEqualTo: _currentUser.uid)
                      .where("seen", isEqualTo: false)
                      .snapshots(),
                  builder: (context, unreadSnapshot) {
                    int unreadCount = 0;
                    if (unreadSnapshot.hasData) {
                      unreadCount = unreadSnapshot.data!.docs.length;
                    }
                    final bool hasUnread = unreadCount > 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: isDark ? const Color(0xFF202C33) : Colors.grey.shade300,
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    otherUserName[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: WAColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  )
                                : null,
                          ),
                          if (isOnline)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                height: 13,
                                width: 13,
                                decoration: BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? WAColors.backgroundDark : Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            )
                        ],
                      ),
                      title: Text(
                        otherUserName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasUnread ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                          fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread ? WAColors.primary : Colors.grey,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(height: 4),
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: WAColors.primary,
                              child: Text(
                                "$unreadCount",
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                          ]
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              receiverId: otherUserId,
                              receiverName: otherUserName,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  // Updates (Status / Stories) Tab View
  Widget _buildUpdatesTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // My Status Header
        StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection("statuses").doc(_currentUser.uid).snapshots(),
          builder: (context, snapshot) {
            final hasStatus = snapshot.hasData && snapshot.data!.exists;
            UserStatus? myStatus;
            
            if (hasStatus) {
              myStatus = UserStatus.fromFirestore(snapshot.data!);
              final cutoff = DateTime.now().subtract(const Duration(hours: 24));
              myStatus = UserStatus(
                uid: myStatus.uid,
                userName: myStatus.userName,
                userPhotoUrl: myStatus.userPhotoUrl,
                items: myStatus.items.where((i) => i.timestamp.isAfter(cutoff)).toList(),
              );
            }

            final myActive = myStatus != null && myStatus.items.isNotEmpty;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: GestureDetector(
                onTap: myActive
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StatusViewerScreen(userStatus: myStatus!),
                          ),
                        )
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: myActive ? WAColors.statusUnseen : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: isDark ? const Color(0xFF202C33) : Colors.grey.shade300,
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
              ),
              title: const Text("My Status", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                myActive ? "Tap to view updates" : "Tap to add status update",
                style: const TextStyle(color: Colors.grey),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle_outline, color: WAColors.primary),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreateStatusScreen()),
                  );
                },
              ),
            );
          },
        ),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Recent updates",
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),

        // Other updates list
        Expanded(
          child: StreamBuilder<List<UserStatus>>(
            stream: _chatService.getStatusesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: WAColors.primary));
              }

              final statuses = snapshot.data?.where((status) => status.uid != _currentUser.uid).toList() ?? [];

              if (statuses.isEmpty) {
                return const Center(
                  child: Text(
                    "No recent updates",
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: statuses.length,
                itemBuilder: (context, index) {
                  final userStatus = statuses[index];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: WAColors.statusUnseen,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 23,
                        backgroundColor: isDark ? const Color(0xFF202C33) : Colors.grey.shade300,
                        backgroundImage: userStatus.userPhotoUrl != null && userStatus.userPhotoUrl!.isNotEmpty
                            ? NetworkImage(userStatus.userPhotoUrl!)
                            : null,
                        child: userStatus.userPhotoUrl == null || userStatus.userPhotoUrl!.isEmpty
                            ? Text(
                                userStatus.userName[0].toUpperCase(),
                                style: const TextStyle(
                                  color: WAColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                    ),
                    title: Text(
                      userStatus.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      DateFormat("h:mm a").format(userStatus.items.last.timestamp),
                      style: const TextStyle(color: Colors.grey),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StatusViewerScreen(userStatus: userStatus),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}