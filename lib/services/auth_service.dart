import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Create user with email and password
  Future<UserCredential> createUserWithEmailAndPassword(
      String email, String password, String displayName, {String role = 'User'}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      // Update display name
      await result.user?.updateDisplayName(displayName);

      // Create user profile in Realtime Database
      await _createUserProfile(result.user!, displayName, email);

      // Save role to Firestore
      await FirebaseFirestore.instance.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'displayName': displayName,
        'role': (role == 'Admin') ? 'Admin' : 'User',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Mirror role to Realtime Database for security rules
      await _database.ref('users/${result.user!.uid}/role').set((role == 'Admin') ? 'Admin' : 'User');

      return result;
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Merge helper for Firestore user doc
  Future<void> mergeUserFirestore(String uid, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  // Create user profile in database
  Future<void> _createUserProfile(
      User user, String displayName, String email) async {
    UserModel userModel = UserModel(
      uid: user.uid,
      email: email,
      displayName: displayName,
      createdAt: DateTime.now(),
    );

    await _database.ref('users/${user.uid}').set(userModel.toMap());
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Get user profile from database
  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DatabaseEvent event = await _database.ref('users/$uid').once();
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> data =
            event.snapshot.value as Map<dynamic, dynamic>;
        return UserModel.fromMap(Map<String, dynamic>.from(data));
      }
      return null;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(
      String uid, Map<String, dynamic> updates) async {
    try {
      await _database.ref('users/$uid').update(updates);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  // Read role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        return data != null ? (data['role'] as String?) : null;
      }
      return null;
    } catch (e) {
      print('Error fetching user role (Firestore): $e');
      return null;
    }
  }

  // Read role from Realtime Database
  Future<String?> getUserRoleFromRealtime(String uid) async {
    try {
      final snap = await _database.ref('users/$uid/role').get();
      if (snap.exists) {
        final val = snap.value;
        return val is String ? val : null;
      }
      return null;
    } catch (e) {
      print('Error fetching user role (RTDB): $e');
      return null;
    }
  }

  Future<bool> isCurrentUserAdmin() async {
    final uid = currentUser?.uid;
    if (uid == null) return false;
    // Try Firestore first
    String? role = await getUserRole(uid);
    // Fallback to RTDB if Firestore blocked
    role ??= await getUserRoleFromRealtime(uid);
    return role == 'Admin';
  }

  // Handle authentication errors
  String _handleAuthError(dynamic e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'Password is too weak.';
        case 'invalid-email':
          return 'Invalid email address.';
        default:
          return 'Authentication failed: ${e.message}';
      }
    }
    return 'An error occurred during authentication.';
  }
}
