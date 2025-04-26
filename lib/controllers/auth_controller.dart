import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Initialize collections if they don't exist
  Future<void> _initializeCollections() async {
    try {
      // Check if users collection exists
      final usersCollection = await _firestore.collection('users').get();
      print(1);
      if (usersCollection.docs.isEmpty) {
        print(2);
        // Create a dummy document to initialize the collection
        await _firestore.collection('users').doc('dummy').set({
          'initialized': true,
          'timestamp': FieldValue.serverTimestamp(),
        });
        // Delete the dummy document
        await _firestore.collection('users').doc('dummy').delete();
      }
    } catch (e) {
      print('Error initializing collections: $e');
      rethrow;
    }
  }

  // Sign up
  Future<UserCredential> signUp(
      String email, String password, String name) async {
    try {
      // Initialize collections if needed
      await _initializeCollections();

      print("5 =================== $name $email $password");
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print(
          "userCredential.user!.uid ===================================== ${userCredential.user!.uid}");
      // Create user profile in Firestore
      await _createUserProfile(userCredential.user!.uid, email, name);

      return userCredential;
    } catch (e) {
      print("error==================${e.toString()}");
      rethrow;
    }
  }

  // Create user profile
  Future<void> _createUserProfile(String uid, String email, String name) async {
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': email,
        'name': name,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating user profile: $e');
      rethrow;
    }
  }

  // Sign in
  Future<UserCredential> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update online status
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Update online status before signing out
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }

      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Update online status
  Future<void> updateOnlineStatus(bool isOnline) async {
    try {
      if (currentUser != null) {
        await _firestore.collection('users').doc(currentUser!.uid).update({
          'isOnline': isOnline,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error updating online status: $e');
      rethrow;
    }
  }

  // Get user profile
  Stream<DocumentSnapshot> getUserProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }
}
