import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // Get all users except current user
  Stream<QuerySnapshot> getAllUsers() {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots();
  }

  // Get or create chat room ID
  Future<String> getChatRoomId(String otherUserId) async {
    // Sort IDs to ensure consistent chat room ID
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    try {
      // Check if chat room exists
      DocumentSnapshot chatRoom = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .get();

      if (!chatRoom.exists) {
        // Get user details
        DocumentSnapshot currentUserDoc = await _firestore
            .collection('users')
            .doc(currentUserId)
            .get();
        DocumentSnapshot otherUserDoc = await _firestore
            .collection('users')
            .doc(otherUserId)
            .get();

        // Create new chat room with user details
        await _firestore.collection('chat_rooms').doc(chatRoomId).set({
          'participants': {
            currentUserId: currentUserDoc.data() as Map<String, dynamic>?,
            otherUserId: otherUserDoc.data() as Map<String, dynamic>?,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('Created new chat room: $chatRoomId');
      } else {
        print('Using existing chat room: $chatRoomId');
      }

      return chatRoomId;
    } catch (e) {
      print('Error creating/getting chat room: $e');
      rethrow;
    }
  }

  // Send message
  Future<void> sendMessage(String chatRoomId, String message) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Update last message in chat room
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      print('Message sent successfully');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages stream
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    print('Getting messages for chat room: $chatRoomId');
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }
}
