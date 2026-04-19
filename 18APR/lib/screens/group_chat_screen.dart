import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_models.dart';
import '../services/group_service.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/web_img_stub.dart' if (dart.library.html) '../widgets/web_img_web.dart';
import 'group_details_screen.dart';
import 'friend_profile_screen.dart';
import 'forward_picker_screen.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class GroupChatScreen extends StatefulWidget {
  final GroupModel group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _groupService = GroupService();
  final _storageService = MediaStorageService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  // Member cache for name display
  final Map<String, UserModel> _membersCache = {};
  bool _membersLoaded = false;

  // Upload
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Audio player state
  String? _playingMessageId;
  PlayerState _audioPlayerState = PlayerState.stopped;

  // Reply
  MessageModel? _replyToMessage;

  // Scroll tracking
  String? _lastScrolledMessageId;

  @override
  void initState() {
    super.initState();
    _loadMembers();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _audioPlayerState = state);
      if (state == PlayerState.completed) {
        setState(() => _playingMessageId = null);
      }
    });
  }

  Future<void> _loadMembers() async {
    final members = await _groupService.getGroupMembers(widget.group.members);
    if (!mounted) return;
    setState(() {
      for (final m in members) {
        _membersCache[m.uid] = m;
      }
      _membersLoaded = true;
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _groupService.sendGroupMessage(
      widget.group.groupId,
      text,
      replyToText: _replyToMessage?.text,
    );
    _messageController.clear();
    setState(() => _replyToMessage = null);
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 50);
    if (image == null) return;

    setState(() { _isUploading = true; _uploadProgress = 0; });
    String? url;
    if (kIsWeb) {
      url = await _storageService.uploadImageHtmlWithProgress(
        await image.readAsBytes(),
        onProgress: (p) => setState(() => _uploadProgress = p),
      );
    } else {
      url = await _storageService.uploadImage(File(image.path));
    }
    setState(() => _isUploading = false);
    if (url != null) {
      _groupService.sendGroupMessage(widget.group.groupId, '📷 Photo',
          type: MessageType.image, mediaUrl: url);
    }
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    setState(() { _isUploading = true; _uploadProgress = 0; });
    String? url;
    if (kIsWeb) {
      if (file.bytes != null) {
        url = await _storageService.uploadFileWebWithProgress(
          file.bytes!, file.name,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      }
    } else if (file.path != null) {
      url = await _storageService.uploadFile(File(file.path!), file.name);
    }
    setState(() => _isUploading = false);
    if (url != null) {
      _groupService.sendGroupMessage(widget.group.groupId, '📄 ${file.name}',
          type: MessageType.document, mediaUrl: url, fileName: file.name);
    }
  }

  void _scrollToBottom(List<MessageModel> messages) {
    if (messages.isEmpty) return;
    final lastId = messages.last.messageId;
    if (_lastScrolledMessageId == lastId) return;
    _lastScrolledMessageId = lastId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GroupDetailsScreen(group: widget.group),
            ),
          ),
          child: Row(
            children: [
              Hero(
                tag: 'group-icon-${widget.group.groupId}',
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: ChatTheme.accent,
                  backgroundImage: (widget.group.groupPhotoUrl != null &&
                          widget.group.groupPhotoUrl!.isNotEmpty)
                      ? NetworkImage(widget.group.groupPhotoUrl!)
                      : null,
                  child: (widget.group.groupPhotoUrl == null || widget.group.groupPhotoUrl!.isEmpty)
                      ? const Icon(Icons.group_rounded, size: 18, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.group.name, style: const TextStyle(fontSize: 16)),
                  Text(
                    '${widget.group.members.length} members',
                    style: const TextStyle(fontSize: 11, color: ChatTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (_isUploading)
            LinearProgressIndicator(
              value: _uploadProgress > 0 ? _uploadProgress : null,
              backgroundColor: Colors.white12,
              color: ChatTheme.primary,
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _groupService.getGroupMessages(widget.group.groupId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs
                    .map((d) => MessageModel.fromMap(d.data() as Map<String, dynamic>))
                    .toList()
                  ..sort((a, b) {
                    final tc = a.timestamp.compareTo(b.timestamp);
                    return tc != 0 ? tc : a.messageId.compareTo(b.messageId);
                  });

                _scrollToBottom(messages);

                final List<dynamic> items = [];
                for (int i = 0; i < messages.length; i++) {
                  if (i == 0 ||
                      !_isSameDay(messages[i].timestamp, messages[i - 1].timestamp)) {
                    items.add(messages[i].timestamp);
                  }
                  items.add(messages[i]);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    if (item is DateTime) return _buildDateDivider(item);
                    final msg = item as MessageModel;
                    final isMe = msg.senderId == _currentUid;
                    return _buildBubble(msg, isMe);
                  },
                );
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(MessageModel message, bool isMe) {
    final senderName = _membersCache[message.senderId]?.name ?? '...';
    final senderPhoto = _membersCache[message.senderId]?.photoUrl;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(message),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Sender avatar (left side only)
              if (!isMe) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: ChatTheme.accent,
                  backgroundImage: (senderPhoto != null && senderPhoto.isNotEmpty)
                      ? NetworkImage(senderPhoto)
                      : null,
                  child: (senderPhoto == null || senderPhoto.isEmpty)
                      ? Text(senderName.isEmpty ? '?' : senderName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 11))
                      : null,
                ),
                const SizedBox(width: 6),
              ],
              // Bubble
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: isMe
                        ? const LinearGradient(
                            colors: [ChatTheme.senderBubble, Color(0xFFE8D7A5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isMe ? null : ChatTheme.receiverBubble,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isMe ? 20 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sender name (group messages only — not for self)
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                          child: GestureDetector(
                            onTap: () {
                              final user = _membersCache[message.senderId];
                              if (user != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => FriendProfileScreen(user: user)),
                                );
                              }
                            },
                            child: Text(
                              senderName.toUpperCase(),
                              style: GoogleFonts.montserrat(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: ChatTheme.accent,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ),
                      // Reply preview
                      if (message.replyToText != null && message.replyToText!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(
                                left: BorderSide(color: ChatTheme.primary, width: 3)),
                          ),
                          child: Text(message.replyToText!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        ),
                      // Content
                      if (message.type == MessageType.image)
                        _buildImageContent(message)
                      else if (message.type == MessageType.audio)
                        _buildAudioContent(message)
                      else if (message.type == MessageType.document)
                        _buildDocumentContent(message)
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Linkify(
                            onOpen: (link) async {
                              final uri = Uri.parse(link.url);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            text: message.isDeleted ? 'This message was deleted' : message.text,
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                              color: message.isDeleted ? ChatTheme.textSecondary : ChatTheme.textPrimary,
                            ),
                            linkStyle: const TextStyle(color: Color(0xFF2196F3), decoration: TextDecoration.underline, fontWeight: FontWeight.bold),
                          ),
                        ),
                      // Timestamp
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4, left: 10),
                        child: Text(
                          DateFormat('HH:mm').format(message.timestamp),
                          style: const TextStyle(fontSize: 9, color: Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageContent(MessageModel message) {
    return InkWell(
      onTap: () => _launchUrl(message.mediaUrl!),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: kIsWeb
            ? buildWebHtmlImage(message.mediaUrl!, width: 220, height: 200, fit: BoxFit.cover)
            : Image.network(message.mediaUrl!, width: 220, height: 200, fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildAudioContent(MessageModel message) {
    final isThis = _playingMessageId == message.messageId;
    final isPlaying = isThis && _audioPlayerState == PlayerState.playing;
    final isPaused = isThis && _audioPlayerState == PlayerState.paused;

    return InkWell(
      onTap: () async {
        if (isPlaying) {
          await _audioPlayer.pause();
        } else if (isPaused) {
          await _audioPlayer.resume();
        } else {
          setState(() => _playingMessageId = message.messageId);
          await _audioPlayer.play(UrlSource(message.mediaUrl!));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isPlaying
                    ? Icons.pause_circle_filled_rounded
                    : Icons.play_circle_fill_rounded,
                key: ValueKey(isPlaying),
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(width: 10),
            if (isPlaying)
              const SpinKitWave(
                color: Colors.white70,
                size: 22,
                type: SpinKitWaveType.center,
              )
            else
              const Text('Voice Note',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentContent(MessageModel message) {
    final fileName = message.fileName ?? 'Document';
    return InkWell(
      onTap: () => _downloadFile(message.mediaUrl!, fileName),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _docIcon(fileName),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                fileName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download_rounded, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Icon _docIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 32);
      case 'xls':
      case 'xlsx':
      case 'csv':
        return const Icon(Icons.table_chart_rounded, color: Colors.green, size: 32);
      case 'apk':
        return const Icon(Icons.android_rounded, color: Colors.lightGreen, size: 32);
      default:
        return const Icon(Icons.insert_drive_file_rounded, color: ChatTheme.primary, size: 32);
    }
  }

  Future<void> _downloadFile(String url, String name) async {
    try {
      if (kIsWeb) {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$name';
      await Dio().download(url, path);
      if (mounted) Navigator.pop(context);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showMessageOptions(MessageModel message) {
    final isMe = message.senderId == _currentUid;
    showModalBottomSheet(
      context: context,
      backgroundColor: ChatTheme.surface,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!message.isDeleted)
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.lightBlueAccent),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyToMessage = message);
              },
            ),
          if (!message.isDeleted)
            ListTile(
              leading: const Icon(Icons.forward_rounded, color: Colors.orangeAccent),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ForwardPickerScreen(message: message)));
              },
            ),
          // Share externally
          if (!message.isDeleted)
            ListTile(
              leading: const Icon(Icons.share_rounded, color: Colors.blueAccent),
              title: const Text('Share Externally'),
              onTap: () {
                Navigator.pop(context);
                if (message.type == MessageType.text) {
                  Share.share(message.text);
                } else if (message.mediaUrl != null) {
                  Share.share('${message.text}\n${message.mediaUrl}');
                }
              },
            ),
          if (message.type == MessageType.text && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white70),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Copied!')));
              },
            ),
          if (isMe && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: const Text('Delete for Everyone'),
              onTap: () {
                Navigator.pop(context);
                _groupService.deleteGroupMessage(widget.group.groupId, message.messageId);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: ChatTheme.background,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: ChatTheme.surface,
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: ChatTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_replyToMessage!.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyToMessage = null),
                    child: const Icon(Icons.close_rounded, size: 16, color: Colors.white54),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: ChatTheme.primary, size: 28),
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: ChatTheme.surface,
                    builder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.camera_alt, color: ChatTheme.primary),
                          title: const Text('Camera'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.camera);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.photo, color: ChatTheme.primary),
                          title: const Text('Gallery'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickImage(ImageSource.gallery);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.description, color: ChatTheme.primary),
                          title: const Text('Document'),
                          onTap: () {
                            Navigator.pop(context);
                            _pickDocument();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Message',
                      fillColor: ChatTheme.surface,
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AudioRecorderWidget(onStop: (recording) async {
                  setState(() { _isUploading = true; _uploadProgress = 0; });
                  String? url;
                  if (recording.bytes != null) {
                    url = await _storageService.uploadAudioWeb(
                        recording.bytes!, recording.fileName);
                  } else if (recording.file != null) {
                    url = await _storageService.uploadAudio(recording.file!);
                  }
                  setState(() => _isUploading = false);
                  if (url != null) {
                    _groupService.sendGroupMessage(widget.group.groupId, '🎤 Voice Note',
                        type: MessageType.audio, mediaUrl: url, fileName: recording.fileName);
                  }
                }),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: ChatTheme.primary,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.black),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      label = '${date.day} ${months[(date.month - 1).clamp(0, 11)]} ${date.year}';
    }
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white12,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
