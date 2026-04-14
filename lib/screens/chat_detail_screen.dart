import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../widgets/audio_recorder_widget.dart';
import '../theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ChatDetailScreen extends StatefulWidget {
  final UserModel otherUser;

  const ChatDetailScreen({super.key, required this.otherUser});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _chatService = ChatService();
  final _storageService = MediaStorageService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      _chatService.sendMessage(_messageController.text, widget.otherUser.uid);
      _messageController.clear();
    }
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      final url = await _storageService.uploadImage(File(image.path));
      if (url != null) {
        _chatService.sendMessage('📷 Photo', widget.otherUser.uid, type: MessageType.image, mediaUrl: url);
      }
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ChatTheme.surface,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: ChatTheme.primary),
            title: const Text('Camera'),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: ChatTheme.primary),
            title: const Text('Gallery'),
            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
          ),
        ],
      ),
    );
  }

  void _playAudio(String url) async {
    await _audioPlayer.play(UrlSource(url));
  }

  void _sendAudio(File file) async {
    final url = await _storageService.uploadAudio(file);
    if (url != null) {
      _chatService.sendMessage('🎤 Voice Note', widget.otherUser.uid, type: MessageType.audio, mediaUrl: url);
    }
  }

  void _showImage(String url) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(url: url)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: ChatTheme.accent,
              child: Text(widget.otherUser.name[0].toUpperCase()),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.otherUser.name),
                Text(
                  widget.otherUser.isOnline ? 'online' : 'offline',
                  style: TextStyle(fontSize: 12, color: widget.otherUser.isOnline ? ChatTheme.primary : ChatTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _chatService.getMessages(widget.otherUser.uid),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final message = MessageModel.fromMap(data);
                    final isMe = message.senderId == currentUserId;

                    return _buildChatBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildChatBubble(MessageModel message, bool isMe) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: InkWell(
        onTap: () {
          if (message.type == MessageType.image) _showImage(message.mediaUrl!);
          if (message.type == MessageType.audio) _playAudio(message.mediaUrl!);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isMe ? ChatTheme.senderBubble : ChatTheme.receiverBubble,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.type == MessageType.image)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: message.mediaUrl!,
                    placeholder: (context, url) => const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator())),
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                )
              else if (message.type == MessageType.audio)
                const Padding(
                  padding: EdgeInsets.all(10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Voice Note', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Text(
                    message.text,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${message.timestamp.hour}:${message.timestamp.minute}',
                      style: const TextStyle(fontSize: 10, color: Colors.white60),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.status == MessageStatus.read ? Icons.done_all : Icons.done,
                        size: 14,
                        color: message.status == MessageStatus.read ? Colors.blue : Colors.white60,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: ChatTheme.background,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: ChatTheme.primary),
            onPressed: _showImageOptions,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Message',
                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AudioRecorderWidget(onStop: _sendAudio),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: ChatTheme.primary,
            child: IconButton(
              icon: const Icon(Icons.send_rounded, color: Colors.black),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final String url;
  const FullScreenImage({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black),
      body: Center(
        child: InteractiveViewer(
          child: CachedNetworkImage(imageUrl: url),
        ),
      ),
    );
  }
}
