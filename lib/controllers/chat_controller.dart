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

  // Send message with enhanced metadata
  Future<void> sendMessage(String chatRoomId, String message) async {
    final timestamp = FieldValue.serverTimestamp();
    final messageDoc = {
      'senderId': currentUserId,
      'message': message.trim(),
      'timestamp': timestamp,
      'read': false, // Explicitly set to false when sending
    };

    try {
      // Add message to chat room
      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add(messageDoc);

      // Update chat room with last message
      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': message.trim(),
        'lastMessageTime': timestamp,
        'lastSenderId': currentUserId,
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Get messages stream with pagination
  Stream<QuerySnapshot> getMessages(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatRoomId, String senderId) async {
    if (senderId == currentUserId) return; // Don't mark own messages

    try {
      final messagesQuery = await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in messagesQuery.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
      // Don't rethrow as this is not critical
    }
  }

  // Update typing status
  Future<void> updateTypingStatus(String chatRoomId, bool isTyping) async {
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'typing.${currentUserId}': isTyping,
    });
  }

  // Get typing status stream
  Stream<DocumentSnapshot> getTypingStatus(String chatRoomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(chatRoomId)
        .snapshots();
  }
}
