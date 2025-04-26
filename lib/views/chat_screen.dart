import 'dart:async';
import 'dart:io';

import 'package:chatapp/controllers/chat_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

class ChatScreen extends StatefulWidget {
  final String chatRoomId;
  final ChatController chatController;

  const ChatScreen({
    super.key,
    required this.chatRoomId,
    required this.chatController,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, VideoPlayerController> _videoControllers = {};
  bool _isUploading = false;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTypingChanged);
  }

  void _onTypingChanged() {
    if (_messageController.text.isNotEmpty && !_isTyping) {
      setState(() => _isTyping = true);
      widget.chatController.updateTypingStatus(widget.chatRoomId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 1000), () {
      setState(() => _isTyping = false);
      widget.chatController.updateTypingStatus(widget.chatRoomId, false);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    for (var controller in _videoControllers.values) {
      controller.dispose();
    }
    _typingTimer?.cancel();
    widget.chatController.updateTypingStatus(widget.chatRoomId, false);
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage(String message, [String mediaType = 'text']) async {
    if (message.trim().isEmpty) return;

    try {
      await widget.chatController.sendMessage(
        widget.chatRoomId,
        message,
        mediaType,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final hasPermission = await _checkAndRequestPermission(source);
    if (!hasPermission) return;

    try {
      setState(() => _isUploading = true);
      final XFile? image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 70,
      );

      if (image != null) {
        await widget.chatController.sendMediaMessage(
          widget.chatRoomId,
          File(image.path),
          'image',
        );
      }
    } catch (e) {
      _handleMediaError(e);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _handleMediaError(dynamic e) {
    if (!mounted) return;

    String errorMessage = 'Failed to send media';
    if (e.toString().contains('size exceeds')) {
      errorMessage = 'File size is too large. Please choose a smaller file.';
    } else if (e.toString().contains('permission')) {
      errorMessage = 'Permission denied. Please check app permissions.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _pickVideo(ImageSource source) async {
    if (!await _checkAndRequestPermission(source)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'Camera permission is required to record videos'
                  : 'Storage permission is required to select videos',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    try {
      setState(() => _isUploading = true);

      final XFile? video = await ImagePicker().pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 5), // Limit video length
      );

      if (video == null) {
        // User cancelled the picker
        return;
      }

      final videoFile = File(video.path);
      await widget.chatController
          .sendMediaMessage(widget.chatRoomId, videoFile, 'video');
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send video';
        if (e.toString().contains('size exceeds')) {
          errorMessage =
              'Video size is too large. Please choose a shorter video.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Permission denied. Please check app permissions.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<bool> _checkAndRequestPermission(ImageSource source) async {
    // Determine which permissions we need based on the source
    final permissions = <Permission>[
      if (source == ImageSource.camera) ...[
        Permission.camera,
        Permission.microphone, // Needed for video recording
      ],
      Permission.storage,
      if (Platform.isAndroid) Permission.photos,
      if (Platform.isIOS) Permission.photosAddOnly,
    ];

    // Check each permission status
    final statuses = await permissions.request();

    // Check if all permissions are granted
    bool allGranted = true;
    final deniedPermissions = <Permission>[];

    for (final permission in permissions) {
      final status = statuses[permission];
      if (status != PermissionStatus.granted) {
        allGranted = false;
        deniedPermissions.add(permission);
      }
    }

    if (allGranted) return true;

    // Handle denied permissions
    if (!mounted) return false;

    // Show a dialog explaining why we need the permissions
    final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permissions Required'),
            content: Text(
              'To ${source == ImageSource.camera ? 'use the camera' : 'access media'}, '
              'please grant the following permissions:\n\n'
              '${deniedPermissions.map((p) => p.toString().split('.').last).join(', ')}\n\n'
              'You can change these permissions in app settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldOpenSettings) {
      await openAppSettings();
      // Re-check permissions after returning from settings
      final newStatuses = await permissions.request();
      return permissions
          .every((p) => newStatuses[p] == PermissionStatus.granted);
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Scaffold(
        appBar: AppBar(
          title: const Text('Chat'),
          actions: [
            IconButton(
              icon: const Icon(Icons.camera_alt),
              onPressed: () => _pickImage(ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.photo_library),
              onPressed: () => _pickImage(ImageSource.gallery),
            ),
            IconButton(
              icon: const Icon(Icons.video_call),
              onPressed: () => _pickVideo(ImageSource.camera),
            ),
            IconButton(
              icon: const Icon(Icons.video_library),
              onPressed: () => _pickVideo(ImageSource.gallery),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: widget.chatController
                    .getMessages(widget.chatRoomId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print(snapshot.error);
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final messages = snapshot.data!.docs;

                  if (messages.isEmpty) {
                    return const Center(
                      child: Text('No messages yet'),
                    );
                  }

                  return ListView.builder(
                    reverse: true,
                    controller: _scrollController,
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final messageData =
                          message.data() as Map<String, dynamic>;
                      final isMe = messageData['senderId'] ==
                          widget.chatController.currentUserId;
                      final messageText =
                          messageData['message'] as String? ?? '';
                      final isRead = messageData['read'] as bool? ?? false;
                      final mediaType =
                          messageData['mediaType'] as String? ?? 'text';
                      final timestamp = messageData['timestamp'] as Timestamp?;
                      final mediaUrl = messageData['mediaUrl'] as String?;

                      String formattedTime = '';
                      if (timestamp != null) {
                        final dateTime = timestamp.toDate();
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final messageDate = DateTime(
                            dateTime.year, dateTime.month, dateTime.day);

                        if (messageDate == today) {
                          formattedTime =
                              '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                        } else {
                          formattedTime =
                              '${dateTime.day}/${dateTime.month} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                        }
                      }

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (mediaType == 'image' && mediaUrl != null)
                                GestureDetector(
                                  onTap: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        child: Image.network(
                                          mediaUrl,
                                          fit: BoxFit.contain,
                                          loadingBuilder:
                                              (context, child, progress) {
                                            if (progress == null) return child;
                                            return Center(
                                              child: CircularProgressIndicator(
                                                value: progress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? progress
                                                            .cumulativeBytesLoaded /
                                                        progress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.6,
                                      maxHeight:
                                          MediaQuery.of(context).size.width *
                                              0.6,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        mediaUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, progress) {
                                          if (progress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: progress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? progress
                                                          .cumulativeBytesLoaded /
                                                      progress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                )
                              else if (mediaType == 'video' && mediaUrl != null)
                                GestureDetector(
                                  onTap: () async {
                                    final controller = _videoControllers[
                                            message.id] ??=
                                        VideoPlayerController.network(mediaUrl);
                                    await controller.initialize();
                                    if (!mounted) return;

                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        child: AspectRatio(
                                          aspectRatio:
                                              controller.value.aspectRatio,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              VideoPlayer(controller),
                                              IconButton(
                                                icon: Icon(
                                                  controller.value.isPlaying
                                                      ? Icons.pause
                                                      : Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 48,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    if (controller
                                                        .value.isPlaying) {
                                                      controller.pause();
                                                    } else {
                                                      controller.play();
                                                    }
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ).then((_) {
                                      controller.pause();
                                      controller.seekTo(Duration.zero);
                                    });
                                  },
                                  child: Container(
                                    constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.6,
                                      maxHeight:
                                          MediaQuery.of(context).size.width *
                                              0.6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black87,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.video_library,
                                          color: Colors.white70,
                                          size: 36,
                                        ),
                                        Icon(
                                          Icons.play_circle_fill,
                                          color: Colors.white,
                                          size: 48,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  messageText,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formattedTime,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isMe
                                          ? Colors.white70
                                          : Colors.black54,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 4),
                                    Icon(
                                      isRead ? Icons.done_all : Icons.done,
                                      size: 16,
                                      color: Colors.white70,
                                    ),
                                  ]
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            if (_isUploading)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 200,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Uploading media...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final message = _messageController.text.trim();
                      if (message.isNotEmpty) {
                        _sendMessage(message);
                      }
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      )
    ]);
  }
}

class VideoPlayerDialog extends StatefulWidget {
  final VideoPlayerController controller;
  final VoidCallback onDispose;

  const VideoPlayerDialog({
    Key? key,
    required this.controller,
    required this.onDispose,
  }) : super(key: key);

  @override
  _VideoPlayerDialogState createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateState);
    widget.controller.play();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateState);
    widget.onDispose();
    super.dispose();
  }

  void _updateState() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: AspectRatio(
        aspectRatio: widget.controller.value.aspectRatio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(widget.controller),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(
                widget.controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.red,
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 50,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                  _isPlaying
                      ? widget.controller.play()
                      : widget.controller.pause();
                });
              },
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
