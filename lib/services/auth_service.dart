import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register User
  Future<UserCredential> register({
    required String name,
    required String email,
    required String password,
  }) async {
    UserCredential userCredential =
        await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore
        .collection("users")
        .doc(userCredential.user!.uid)
        .set({
      "uid": userCredential.user!.uid,
      "name": name,
      "email": email,
      "createdAt": FieldValue.serverTimestamp(),
      "status": "online",
      "lastActive": FieldValue.serverTimestamp(),
      "photoUrl": "",
      "about": "Hey there! I am using UsChat.",
    });

    return userCredential;
  }

  // Login
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    final creds = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await updatePresence(true);
    return creds;
  }

  // Logout
  Future<void> logout() async {
    await updatePresence(false);
    await _auth.signOut();
  }

  // Update Presence Status
  Future<void> updatePresence(bool isOnline) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _firestore.collection("users").doc(user.uid).update({
          "status": isOnline ? "online" : "offline",
          "lastActive": FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print("Error updating presence: $e");
      }
    }
  }

  // Current User
  User? get currentUser => _auth.currentUser;
}