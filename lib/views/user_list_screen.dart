import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/chat_controller.dart';
import 'chat_screen.dart';

class UserListScreen extends StatelessWidget {
  final ChatController _chatController = ChatController();

  UserListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select User'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _chatController.getAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final userData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final userId = snapshot.data!.docs[index].id;

              return ListTile(
                leading: CircleAvatar(
                  child: Text(userData['name']?[0] ?? '?'),
                ),
                title: Text(userData['name'] ?? 'Unknown'),
                subtitle: Text(userData['email'] ?? ''),
                onTap: () async {
                  // Get chat room ID
                  String chatRoomId = await _chatController.getChatRoomId(userId);
                  
                  // Navigate to chat screen
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatRoomId: chatRoomId,
                          otherUserName: userData['name'] ?? 'Unknown',
                        ),
                      ),
                    );
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}
