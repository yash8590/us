import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';
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

  @override
  void initState() {
    super.initState();
    // Update the push notification device token in Firestore
    NotificationService().updateToken();
  }

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

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final activeColor = WAColors.primary;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _isSearching = false;
          _searchQuery = "";
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(isDark ? 0.15 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? selectedIcon : unselectedIcon,
              color: isSelected ? activeColor : Colors.grey.shade500,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
      "us",
      "Updates",
      "Settings",
    ];

    return Scaffold(
      backgroundColor: isDark ? WAColors.backgroundDark : WAColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? WAColors.backgroundDark : WAColors.backgroundLight,
        centerTitle: true,
        title: _isSearching && _currentIndex == 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 42,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151B2C) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: "Search chats...",
                    hintStyle: TextStyle(color: isDark ? Colors.grey.shade500 : Colors.grey.shade600, fontSize: 15),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.trim().toLowerCase();
                    });
                  },
                ),
              )
            : Text(
                titles[_currentIndex],
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: _currentIndex == 0 ? 28 : 22,
                  letterSpacing: _currentIndex == 0 ? -1.5 : -0.5,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
        actions: [
          if (_currentIndex == 0)
            IconButton(
              icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
              onPressed: () {
                setState(() {
                  _isSearching = !_isSearching;
                  _searchQuery = "";
                  _searchController.clear();
                });
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: tabs[_currentIndex],
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF151B2C).withOpacity(0.9) : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, "Chats", isDark),
                _buildNavItem(1, Icons.star_outline_rounded, Icons.star_rounded, "Updates", isDark),
                _buildNavItem(2, Icons.settings_outlined, Icons.settings_rounded, "Settings", isDark),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              backgroundColor: WAColors.primary,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SelectContactScreen()),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
              label: const Text("New Chat", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : _currentIndex == 1
              ? FloatingActionButton.extended(
                  backgroundColor: WAColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CreateStatusScreen()),
                    );
                  },
                  icon: const Icon(Icons.camera_alt_outlined, size: 20),
                  label: const Text("Add Status", style: TextStyle(fontWeight: FontWeight.bold)),
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
                String? mood;

                if (userSnapshot.hasData && userSnapshot.data!.exists) {
                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;
                  otherUserName = userData["name"] ?? "User";
                  photoUrl = userData["photoUrl"] ?? "";
                  isOnline = userData["status"] == "online";
                  mood = userData["mood"] as String?;
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

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF151B2C).withOpacity(0.4) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.08 : 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        leading: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: hasUnread ? WAColors.primary.withOpacity(0.5) : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 26,
                                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade200,
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
                            ),
                            if (isOnline)
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  height: 13,
                                  width: 13,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981), // Neon Green
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark ? const Color(0xFF151B2C) : Colors.white,
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              )
                          ],
                        ),
                        title: Row(
                          children: [
                            Text(
                              otherUserName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (mood != null && mood.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: WAColors.primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  mood.split(" ").last, // Display only the emoji
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ]
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: hasUnread ? (isDark ? Colors.white : Colors.black87) : Colors.grey.shade500,
                              fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: hasUnread ? WAColors.primary : Colors.grey.shade400,
                                fontWeight: hasUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (hasUnread) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: WAColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  "$unreadCount",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
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

        // Countdowns Section
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("chats")
              .where("participants", arrayContains: _currentUser.uid)
              .snapshots(),
          builder: (context, chatSnapshot) {
            if (!chatSnapshot.hasData || chatSnapshot.data!.docs.isEmpty) {
              return const SizedBox.shrink();
            }
            final chatId = chatSnapshot.data!.docs.first.id;
            return Column(
              children: [
                _buildCountdownsSection(context, chatId, isDark),
                const Divider(height: 24),
              ],
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

  Widget _buildCountdownsSection(BuildContext context, String chatId, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .collection("countdowns")
          .orderBy("date")
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Our Countdowns 💖",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _showAddCountdownDialog(context, chatId),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.add, size: 14, color: WAColors.primary),
                    label: const Text(
                      "Add",
                      style: TextStyle(color: WAColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (docs.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF151B2C).withOpacity(0.4) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Text(
                    "No active countdowns. Add one to count down special dates together!",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.3),
                  ),
                ),
              )
            else
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final docId = docs[index].id;
                    final title = data["title"] ?? "";
                    final date = (data["date"] as Timestamp).toDate();
                    final iconName = data["icon"] ?? "heart";
                    
                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final target = DateTime(date.year, date.month, date.day);
                    final diffDays = target.difference(today).inDays;

                    String daysStr = "";
                    if (diffDays == 0) {
                      daysStr = "Today! 🎉";
                    } else if (diffDays == 1) {
                      daysStr = "1 day left";
                    } else if (diffDays < 0) {
                      daysStr = "${diffDays.abs()} days ago";
                    } else {
                      daysStr = "$diffDays days left";
                    }

                    IconData displayIcon = Icons.favorite_rounded;
                    switch (iconName) {
                      case "plane":
                        displayIcon = Icons.airplanemode_active_rounded;
                        break;
                      case "cake":
                        displayIcon = Icons.cake_rounded;
                        break;
                      case "star":
                        displayIcon = Icons.star_rounded;
                        break;
                      case "movie":
                        displayIcon = Icons.movie_creation_rounded;
                        break;
                      case "drink":
                        displayIcon = Icons.local_bar_rounded;
                        break;
                    }

                    return Container(
                      width: 160,
                      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [const Color(0xFFFFF1F2), Colors.white],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? WAColors.primary.withOpacity(0.2) : Colors.pink.shade50,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isDark ? 0.1 : 0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: WAColors.primary.withOpacity(0.12),
                                child: Icon(displayIcon, color: WAColors.primary, size: 16),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    daysStr,
                                    style: TextStyle(
                                      color: diffDays >= 0 ? WAColors.accent : Colors.grey,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                              onPressed: () => FirebaseFirestore.instance
                                  .collection("chats")
                                  .doc(chatId)
                                  .collection("countdowns")
                                  .doc(docId)
                                  .delete(),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showAddCountdownDialog(BuildContext context, String chatId) async {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    String selectedIcon = "heart";

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Create Countdown", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: "Title (e.g. Anniversary, Next Date)",
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Date Picker Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Date:", style: TextStyle(fontWeight: FontWeight.w500)),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(DateFormat("MMM d, y").format(selectedDate)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 365)),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Icon Picker Selection
                  const Text("Icon:", style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildIconButton(setDialogState, "heart", Icons.favorite_rounded, selectedIcon, (val) => selectedIcon = val),
                      _buildIconButton(setDialogState, "plane", Icons.airplanemode_active_rounded, selectedIcon, (val) => selectedIcon = val),
                      _buildIconButton(setDialogState, "cake", Icons.cake_rounded, selectedIcon, (val) => selectedIcon = val),
                      _buildIconButton(setDialogState, "star", Icons.star_rounded, selectedIcon, (val) => selectedIcon = val),
                      _buildIconButton(setDialogState, "movie", Icons.movie_creation_rounded, selectedIcon, (val) => selectedIcon = val),
                      _buildIconButton(setDialogState, "drink", Icons.local_bar_rounded, selectedIcon, (val) => selectedIcon = val),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: WAColors.primary),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    await FirebaseFirestore.instance
                        .collection("chats")
                        .doc(chatId)
                        .collection("countdowns")
                        .add({
                      "title": title,
                      "date": Timestamp.fromDate(selectedDate),
                      "icon": selectedIcon,
                      "createdBy": _currentUser.uid,
                    });

                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Save", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildIconButton(StateSetter setDialogState, String iconName, IconData iconData, String currentSelected, Function(String) onSelect) {
    final isSelected = iconName == currentSelected;
    return GestureDetector(
      onTap: () {
        setDialogState(() {
          onSelect(iconName);
        });
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected ? WAColors.primary.withOpacity(0.15) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? WAColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          iconData,
          color: isSelected ? WAColors.primary : Colors.grey,
          size: 18,
        ),
      ),
    );
  }
}