import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:chatapp/services/media_upload_service.dart';

class ChatController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUserId => _auth.currentUser?.uid ?? '';

  Stream<QuerySnapshot> getAllUsers() {
    return _firestore
        .collection('users')
        .where('uid', isNotEqualTo: currentUserId)
        .snapshots();
  }

  Future<String> getChatRoomId(String otherUserId) async {
    List<String> ids = [currentUserId, otherUserId];
    ids.sort();
    String chatRoomId = ids.join('_');

    try {
      DocumentSnapshot chatRoom =
          await _firestore.collection('chat_rooms').doc(chatRoomId).get();

      if (!chatRoom.exists) {
        DocumentSnapshot currentUserDoc =
            await _firestore.collection('users').doc(currentUserId).get();
        DocumentSnapshot otherUserDoc =
            await _firestore.collection('users').doc(otherUserId).get();

        await _firestore.collection('chat_rooms').doc(chatRoomId).set({
          'participants': {
            currentUserId: currentUserDoc.data() as Map<String, dynamic>?,
            otherUserId: otherUserDoc.data() as Map<String, dynamic>?,
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      return chatRoomId;
    } catch (e) {
      print('Error creating/getting chat room: $e');
      rethrow;
    }
  }

  Future<void> sendMessage(String roomId, String message,
      [String mediaType = 'text']) async {
    try {
      await _firestore
          .collection('chat_rooms')
          .doc(roomId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'message': message,
        'mediaType': mediaType,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }

  Query<Map<String, dynamic>> getMessages(String roomId) {
    return _firestore
        .collection('chat_rooms')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true);
  }

  Future<void> sendMediaMessage(
      String chatRoomId, File file, String mediaType) async {
    try {
      String? mediaUrl;

      if (mediaType == 'image') {
        mediaUrl = await MediaUploadService.uploadImage(file);
      } else if (mediaType == 'video') {
        mediaUrl = await MediaUploadService.uploadVideo(file);
      }

      if (mediaUrl == null) {
        throw Exception('Failed to upload media');
      }

      await _firestore
          .collection('chat_rooms')
          .doc(chatRoomId)
          .collection('messages')
          .add({
        'senderId': currentUserId,
        'message': mediaType == 'image' ? '📷 Photo' : '📹 Video',
        'mediaType': mediaType,
        'mediaUrl': mediaUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await _firestore.collection('chat_rooms').doc(chatRoomId).update({
        'lastMessage': mediaType == 'image' ? '📷 Photo' : '📹 Video',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': currentUserId,
      });
    } catch (e) {
      debugPrint('Error sending media message: $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatRoomId, String senderId) async {
    if (senderId == currentUserId) return;

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
    }
  }

  Future<void> updateTypingStatus(String chatRoomId, bool isTyping) async {
    await _firestore.collection('chat_rooms').doc(chatRoomId).update({
      'typing.${currentUserId}': isTyping,
    });
  }

  Stream<DocumentSnapshot> getTypingStatus(String chatRoomId) {
    return _firestore.collection('chat_rooms').doc(chatRoomId).snapshots();
  }
}
