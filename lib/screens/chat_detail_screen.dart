import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // Web check
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart'; // Add file picker
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../widgets/audio_recorder_widget.dart';
import '../theme/app_theme.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../widgets/web_img_stub.dart' if (dart.library.html) '../widgets/web_img_web.dart';
import 'personal_hub_screen.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'friend_profile_screen.dart';
import 'forward_picker_screen.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

class ChatDetailScreen extends StatefulWidget {
  final UserModel otherUser;
  const ChatDetailScreen({super.key, required this.otherUser});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final _messageController = TextEditingController();
  final _searchController = TextEditingController();
  final _messagesScrollController = ScrollController();
  final _chatService = ChatService();
  final _storageService = MediaStorageService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final NotificationService _notificationService = NotificationService();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
  bool _isSearching = false;
  String _internalSearchQuery = "";
  bool _isRinging = false;     // receiver: true when being rung
  bool _isSenderRinging = false; // sender: true while ring is active
  String? _lastVisibleMessageId;

  // Audio player state (M2)
  String? _playingMessageId;
  PlayerState _audioPlayerState = PlayerState.stopped;
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  StreamSubscription? _ringSignalSub;
  StreamSubscription? _senderRingSignalSub;

  // Reply-to
  MessageModel? _replyToMessage;

  // Upload progress
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // Recording status
  bool _isRecordingVoice = false;
  Timer? _typingTimer;

  // Pagination — older messages loaded via "Load more"
  final List<MessageModel> _olderMessages = [];
  bool _isLoadingOlder = false;
  bool _hasMoreOlder = true;

  @override
  void initState() {
    super.initState();
    _listenMyRingSignal();
    _listenSenderRingStatus();
    
    // Ensure the chat room exists and is synced for new users
    if (widget.otherUser.uid.isNotEmpty) {
      _chatService.syncChatThread(widget.otherUser.uid);
    }

    // M2: track audio player state changes
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _audioPlayerState = state);
      if (state == PlayerState.completed) {
        setState(() {
          _playingMessageId = null;
          _audioPosition = Duration.zero;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _audioDuration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _audioPosition = p);
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (widget.otherUser.uid.isEmpty) return; // guard: unknown user
    _chatService.sendMessage(
      text,
      widget.otherUser.uid,
      replyToMessageId: _replyToMessage?.messageId,
      replyToText: _replyToMessage?.text,
    );
    _messageController.clear();
    setState(() => _replyToMessage = null);
    _chatService.setUserStatus(widget.otherUser.uid, UserChatStatus.idle);
    _typingTimer?.cancel();
  }

  void _onTypingChanged(String value) {
    _chatService.setUserStatus(widget.otherUser.uid, value.isNotEmpty ? UserChatStatus.typing : UserChatStatus.idle);
    _typingTimer?.cancel();
    if (value.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 5), () {
        _chatService.setUserStatus(widget.otherUser.uid, UserChatStatus.idle);
      });
    }
  }

  // ─── Ring Signal Handlers ────────────────────────────────────────────────

  /// Receiver listens to ring_signals/{myUid} — reacts when sender rings us.
  void _listenMyRingSignal() {
    _ringSignalSub = _chatService.listenMyRingSignal().listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data();
      if (data == null) return;
      final active = data['active'] as bool? ?? false;
      final senderId = data['senderId'] as String?;
      final startedAt = data['startedAt'];
      // Only react to rings from the person we are currently chatting with
      if (senderId != widget.otherUser.uid) return;
      // Freshness guard — ignore stale ring signals older than 120 s
      DateTime? startTime;
      if (startedAt is Timestamp) startTime = startedAt.toDate();
      final isFresh = startTime != null &&
          DateTime.now().difference(startTime).inSeconds < 120;
      if (active && isFresh && !_isRinging) {
        setState(() => _isRinging = true);
        if (!kIsWeb) _notificationService.showRingNotification(widget.otherUser.name);
      } else if (!active && _isRinging) {
        setState(() => _isRinging = false);
        if (!kIsWeb) _notificationService.cancelRingNotification();
      }
    });
  }

  /// Sender listens to ring_signals/{receiverId} — knows when receiver stopped ring.
  void _listenSenderRingStatus() {
    _senderRingSignalSub =
        _chatService.listenRingSignalOf(widget.otherUser.uid).listen((snap) {
      if (!snap.exists || !mounted) return;
      final data = snap.data();
      if (data == null) return;
      final active = data['active'] as bool? ?? false;
      if (!active && _isSenderRinging) {
        setState(() => _isSenderRinging = false);
      }
    });
  }

  void _triggerRing() {
    if (_isSenderRinging) return;
    _chatService.sendRingSignal(widget.otherUser.uid);
    setState(() => _isSenderRinging = true);
    // Auto-cancel after 90 seconds
    Future.delayed(const Duration(seconds: 90), () {
      if (mounted && _isSenderRinging) _cancelRing();
    });
  }

  /// Sender cancels the ring they started.
  void _cancelRing() {
    _chatService.stopRingSignal(widget.otherUser.uid);
    setState(() => _isSenderRinging = false);
  }

  /// Receiver stops the incoming ring.
  void _stopRinging() {
    setState(() => _isRinging = false);
    if (!kIsWeb) _notificationService.cancelRingNotification();
    // Write active=false so sender also sees the ring was stopped
    _chatService.stopRingSignal(currentUserId);
  }

  void _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 50);
    if (image != null) {
      setState(() { _isUploading = true; _uploadProgress = 0.0; });
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
        _chatService.sendMessage('📷 Photo', widget.otherUser.uid, type: MessageType.image, mediaUrl: url);
      }
    }
  }

  // NEW: Send Documents (PDF, Excel, etc.)
  void _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );

    if (result != null) {
      if (result.files.isEmpty) return;

      String? url;
      final selectedFile = result.files.first;
      String fileName = selectedFile.name;

      setState(() { _isUploading = true; _uploadProgress = 0.0; });
      if (kIsWeb) {
        if (selectedFile.bytes == null) { setState(() => _isUploading = false); return; }
        url = await _storageService.uploadFileWebWithProgress(
          selectedFile.bytes!, fileName,
          onProgress: (p) => setState(() => _uploadProgress = p),
        );
      } else {
        if (selectedFile.path == null) { setState(() => _isUploading = false); return; }
        url = await _storageService.uploadFile(File(selectedFile.path!), fileName);
      }
      setState(() => _isUploading = false);

      if (url != null) {
        _chatService.sendMessage('📄 $fileName', widget.otherUser.uid, type: MessageType.document, mediaUrl: url, fileName: fileName);
      }
    }
  }

  void _showMessageOptions(MessageModel message) {
    bool isMe = message.senderId == currentUserId;
    bool canMod = DateTime.now().difference(message.timestamp).inHours < 48;

    showModalBottomSheet(
      context: context,
      backgroundColor: ChatTheme.surface,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildReactionRow(message.messageId),
          const Divider(color: Colors.white12),
          // Reply
          if (!message.isDeleted)
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: Colors.lightBlueAccent),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _replyToMessage = message);
              },
            ),
          // Forward
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
          // Star / Unstar
          ListTile(
            leading: Icon(
              message.isStarred ? Icons.star_rounded : Icons.star_border_rounded,
              color: Colors.amber,
            ),
            title: Text(message.isStarred ? 'Unstar' : 'Star'),
            onTap: () {
              Navigator.pop(context);
              _chatService.toggleStarMessage(widget.otherUser.uid, message.messageId, message.isStarred);
            },
          ),
          // Copy text
          if (message.type == MessageType.text && !message.isDeleted)
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.white70),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
              },
            ),
          if (isMe && !message.isDeleted && canMod && message.type == MessageType.text)
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Colors.blue),
              title: const Text('Edit Message'),
              onTap: () { Navigator.pop(context); _showEditDialog(message); },
            ),
          if (isMe && !message.isDeleted && canMod)
            ListTile(
              leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
              title: const Text('Delete for Everyone'),
              onTap: () { Navigator.pop(context); _chatService.deleteForEveryone(widget.otherUser.uid, message.messageId, mediaUrl: message.mediaUrl); },
            ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
            title: const Text('Delete for Me'),
            onTap: () {
              Navigator.pop(context);
              _chatService.deleteForMe(widget.otherUser.uid, message.messageId);
            },
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
  }

  Widget _buildReactionRow(String messageId) {
    List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: emojis.map((e) => GestureDetector(
          onTap: () { _chatService.addReaction(widget.otherUser.uid, messageId, e); Navigator.pop(context); },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(e, style: const TextStyle(fontSize: 24)),
          ),
        )).toList(),
      ),
    );
  }

  void _showEditDialog(MessageModel message) {
    final editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ChatTheme.surface,
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Type new message...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              _chatService.editMessage(widget.otherUser.uid, message.messageId, editController.text);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFile(String url, String fileName) async {
    if (kIsWeb) {
      // In web, some browsers block direct download via launchUrl.
      // We recommend opening in a new tab if it's an image/media.
      final Uri uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    try {
      if (kIsWeb) {
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      // Progress overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$fileName';
      
      await Dio().download(url, path);
      
      if (mounted) Navigator.pop(context); // Close dialog

      if (fileName.toLowerCase().endsWith('.apk')) {
        await OpenFilex.open(path);
      } else {
        await OpenFilex.open(path);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog if open
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    }
  }

  Future<void> _loadOlderMessages(List<MessageModel> currentMessages) async {
    if (_isLoadingOlder || currentMessages.isEmpty) return;
    setState(() => _isLoadingOlder = true);
    final oldest = currentMessages.first.timestamp;
    final older = await _chatService.loadOlderMessages(widget.otherUser.uid, oldest);
    setState(() {
      _isLoadingOlder = false;
      if (older.isEmpty) {
        _hasMoreOlder = false;
      } else {
        for (final m in older) {
          if (!_olderMessages.any((o) => o.messageId == m.messageId)) {
            _olderMessages.add(m);
          }
        }
      }
    });
  }

  void _scrollToLatestMessage(List<MessageModel> messages) {
    if (messages.isEmpty) {
      return;
    }

    final newestMessageId = messages.last.messageId;
    if (_lastVisibleMessageId == newestMessageId) {
      return;
    }
    _lastVisibleMessageId = newestMessageId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) {
        return;
      }
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _ringSignalSub?.cancel();
    _senderRingSignalSub?.cancel();
    _chatService.setUserStatus(widget.otherUser.uid, UserChatStatus.idle);
    _audioPlayer.dispose();
    _messageController.dispose();
    _searchController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  void _scrollToMessage(String msgId) {
    // Basic navigation: Check if the message is already in our list
    // and attempt to scroll. For complex apps, use scrollable_positioned_list.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Jumping to message...'), duration: Duration(milliseconds: 500)),
    );
    // In a production app, we would use an ItemScrollController here.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.black87),
              decoration: const InputDecoration(hintText: 'Search chat...', border: InputBorder.none),
              onChanged: (val) => setState(() => _internalSearchQuery = val),
            )
          : GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FriendProfileScreen(user: widget.otherUser)),
              ),
              child: Row(
                children: [
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.otherUser.uid)
                        .snapshots(),
                    builder: (context, snap) {
                      String? photoUrl = widget.otherUser.photoUrl;
                      String name = widget.otherUser.name;
                      if (snap.hasData && snap.data!.exists) {
                        final d = snap.data!.data()!;
                        photoUrl = d['photoUrl'] as String?;
                        name = d['name'] as String? ?? name;
                      }
                      return CircleAvatar(
                        radius: 18,
                        backgroundColor: ChatTheme.accent,
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                            ? NetworkImage(photoUrl)
                            : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(name.isEmpty ? '?' : name[0].toUpperCase())
                            : null,
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.otherUser.name, style: const TextStyle(fontSize: 16)),
                      StreamBuilder<String>(
                        stream: _chatService.getPartnerStatus(widget.otherUser.uid),
                        builder: (context, snap) {
                          final status = snap.data ?? '';
                          final isStatusActive = status.isNotEmpty;
                          return Text(
                            isStatusActive
                              ? status.toLowerCase()
                              : (widget.otherUser.isOnline ? 'online' : _formatLastSeen(widget.otherUser.lastSeen)),
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: isStatusActive ? FontStyle.italic : FontStyle.normal,
                              color: isStatusActive
                                ? Colors.greenAccent
                                : (widget.otherUser.isOnline ? ChatTheme.primary : ChatTheme.textSecondary),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_rounded, color: Colors.amber),
            tooltip: 'Starred',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => StarredMessagesScreen(otherUser: widget.otherUser)),
            ),
          ),
          StreamBuilder<ConnectionModel?>(
            stream: _chatService.getConnection(widget.otherUser.uid),
            builder: (context, connSnap) {
              final isFriend = connSnap.data?.status == ConnectionStatus.accepted;
              return IconButton(
                icon: Icon(
                  _isSenderRinging
                      ? Icons.notifications_off_rounded
                      : Icons.notifications_active_rounded,
                  color: !isFriend 
                    ? Colors.black12
                    : (_isSenderRinging ? Colors.redAccent : Colors.orangeAccent),
                ),
                tooltip: !isFriend ? 'Add friend to ring' : (_isSenderRinging ? 'Cancel Ring' : 'Send Wake-up Ring'),
                onPressed: isFriend 
                  ? (_isSenderRinging ? _cancelRing : _triggerRing)
                  : null,
              );
            }
          ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _internalSearchQuery = '';
            }),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              if (val == 'gallery') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MediaGalleryScreen(otherUser: widget.otherUser)),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'gallery',
                child: Row(
                  children: [
                    Icon(Icons.photo_library_outlined, color: Colors.blueAccent),
                    SizedBox(width: 12),
                    Text('Media Gallery', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_isUploading)
                LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  backgroundColor: Colors.white12,
                  color: ChatTheme.primary,
                ),
              // Sender ringing status banner — shows while ring is active
              if (_isSenderRinging)
                Container(
                  color: Colors.orange.withOpacity(0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.orangeAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '🔔 Ringing ${widget.otherUser.name}...',
                          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _cancelRing,
                        icon: const Icon(Icons.stop_circle_rounded, size: 18),
                        label: const Text('Cancel'),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMessages(widget.otherUser.uid),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;
                    List<MessageModel> messages = docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final m = MessageModel.fromMap(data);
                      final deletedFor = List.from(data['deletedFor'] ?? []);
                      return (model: m, isHidden: deletedFor.contains(currentUserId));
                    }).where((item) {
                      return !item.isHidden &&
                          item.model.text.toLowerCase().contains(_internalSearchQuery.toLowerCase());
                    }).map((item) => item.model).toList();

                    messages.sort((a, b) {
                      final tc = a.timestamp.compareTo(b.timestamp);
                      return tc != 0 ? tc : a.messageId.compareTo(b.messageId);
                    });

                    // Merge older (paginated) messages with live stream messages
                    final allMessages = <MessageModel>[..._olderMessages];
                    for (final m in messages) {
                      if (!allMessages.any((o) => o.messageId == m.messageId)) {
                        allMessages.add(m);
                      }
                    }
                    allMessages.sort((a, b) {
                      final tc = a.timestamp.compareTo(b.timestamp);
                      return tc != 0 ? tc : a.messageId.compareTo(b.messageId);
                    });

                    if (allMessages.isNotEmpty) _scrollToLatestMessage(allMessages);

                    // Build flat list interleaved with date dividers
                    final List<dynamic> items = [];
                    // "Load more" button at top
                    if (_hasMoreOlder) {
                      items.add('__load_more__');
                    }
                    for (int i = 0; i < allMessages.length; i++) {
                      if (i == 0 || !_isSameDay(allMessages[i].timestamp, allMessages[i - 1].timestamp)) {
                        items.add(allMessages[i].timestamp);
                      }
                      items.add(allMessages[i]);
                    }

                    return ListView.builder(
                      controller: _messagesScrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        if (item == '__load_more__') {
                          return Center(
                            child: TextButton.icon(
                              onPressed: _isLoadingOlder ? null : () => _loadOlderMessages(allMessages),
                              icon: _isLoadingOlder
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.expand_less_rounded, size: 18),
                              label: Text(_isLoadingOlder ? 'Loading...' : 'Load older messages'),
                              style: TextButton.styleFrom(foregroundColor: ChatTheme.textSecondary),
                            ),
                          );
                        }
                        if (item is DateTime) return _buildDateDivider(item);
                        final message = item as MessageModel;
                        return _buildChatBubble(message, message.senderId == currentUserId);
                      },
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                bottom: true,
                child: StreamBuilder<bool>(
                  stream: _chatService.isBlockedBy(widget.otherUser.uid),
                  builder: (context, blockSnap) {
                    if (blockSnap.data == true) {
                      return _buildBlockBanner('You cannot send messages to this user.');
                    }
                    return StreamBuilder<bool>(
                      stream: _chatService.amIBlocking(widget.otherUser.uid),
                      builder: (context, blockingMeSnap) {
                        if (blockingMeSnap.data == true) {
                          return _buildBlockBanner('You have blocked this contact.', canUnblock: true);
                        }
                        return StreamBuilder<ConnectionModel?>(
                          stream: _chatService.getConnection(widget.otherUser.uid),
                          builder: (context, connSnap) {
                            final conn = connSnap.data;
                            if (conn == null) {
                              return _buildConnectionPrompt(
                                'Send a friend request to start chatting.',
                                'ADD FRIEND',
                                () => _chatService.sendFriendRequest(widget.otherUser.uid),
                              );
                            }
                            if (conn.status == ConnectionStatus.pending) {
                              if (conn.senderId == currentUserId) {
                                return _buildConnectionPrompt(
                                  'Friend request sent. Waiting for response...',
                                  'CANCEL',
                                  () => _chatService.unfriend(widget.otherUser.uid),
                                );
                              } else {
                                return _buildConnectionPrompt(
                                  '${widget.otherUser.name} wants to be friends.',
                                  'ACCEPT',
                                  () => _chatService.acceptFriendRequest(widget.otherUser.uid),
                                );
                              }
                            }

                            if (conn.status == ConnectionStatus.unfriendedBySender || conn.status == ConnectionStatus.unfriendedByReceiver) {
                              bool unfriendedByMe = (currentUserId == conn.senderId && conn.status == ConnectionStatus.unfriendedBySender) ||
                                                   (currentUserId == conn.receiverId && conn.status == ConnectionStatus.unfriendedByReceiver);
                              
                              if (unfriendedByMe) {
                                return _buildConnectionPrompt(
                                  'You unfriended this contact.',
                                  'RE-FRIEND DIRECTLY',
                                  () => _chatService.reFriend(widget.otherUser.uid),
                                );
                              } else {
                                return _buildConnectionPrompt(
                                  '${widget.otherUser.name} unfriended you.',
                                  'SEND FRIEND REQUEST',
                                  () => _chatService.sendFriendRequest(widget.otherUser.uid),
                                );
                              }
                            }
                            
                            // Accepted
                            return _buildMessageInput();
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isRinging) _buildRingOverlay(),
        ],
      ),
    );
  }

  Widget _buildRingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.92),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated bell icon
          const Icon(Icons.notifications_active_rounded,
              size: 100, color: Colors.orangeAccent),
          const SizedBox(height: 24),
          Text(
            '📞 ${widget.otherUser.name}',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          const Text(
            'is ringing you — Wake up!',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _stopRinging,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            icon: const Icon(Icons.stop_circle_rounded, size: 24),
            label: const Text('Stop Ringing',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(MessageModel message, bool isMe) {
    if (message.type == MessageType.ring) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(20)),
          child: Text(
            isMe ? 'You rang ${widget.otherUser.name}' : '${widget.otherUser.name} rang you',
            style: const TextStyle(fontSize: 12, color: Colors.orangeAccent),
          ),
        ),
      );
    }

    final isHighlighted = _internalSearchQuery.isNotEmpty &&
        message.text.toLowerCase().contains(_internalSearchQuery.toLowerCase());

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(message),
        child: Container(
          margin: const EdgeInsets.only(bottom: 22),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? Colors.orange.withOpacity(0.5)
                      : (isMe ? ChatTheme.senderBubble : ChatTheme.receiverBubble),
                  borderRadius: BorderRadius.circular(16).copyWith(
                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Quoted reply preview
                    if (message.replyToText != null && message.replyToText!.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          if (message.replyToMessageId != null) {
                            _scrollToMessage(message.replyToMessageId!);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(left: 8, right: 8, top: 6, bottom: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: const Border(left: BorderSide(color: ChatTheme.primary, width: 3)),
                          ),
                          child: Text(
                            message.replyToText!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ),
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
                        text: message.text,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          fontStyle: message.isDeleted ? FontStyle.italic : FontStyle.normal,
                          color: message.isDeleted ? ChatTheme.textSecondary : ChatTheme.textPrimary,
                        ),
                        linkStyle: const TextStyle(color: Color(0xFF2196F3), decoration: TextDecoration.underline, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8, bottom: 4, left: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(message.timestamp),
                            style: const TextStyle(fontSize: 9, color: Colors.black),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(_getStatusIcon(message.status), size: 12, color: _getStatusColor(message.status)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (message.reactions.isNotEmpty) _buildReactionBadge(message, isMe),
              if (message.isStarred)
                Positioned(
                  top: -6,
                  right: isMe ? 6 : null,
                  left: isMe ? null : 6,
                  child: const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentContent(MessageModel message) {
    final fileName = message.fileName ?? 'Document';
    return InkWell(
      onTap: () => _downloadFile(message.mediaUrl!, fileName),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            _docIcon(fileName),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(color: ChatTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(_docTypeLabel(fileName), style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
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
      case 'doc':
      case 'docx':
        return const Icon(Icons.description_rounded, color: Colors.blueAccent, size: 32);
      case 'ppt':
      case 'pptx':
        return const Icon(Icons.slideshow_rounded, color: Colors.deepOrange, size: 32);
      case 'zip':
      case 'rar':
      case '7z':
        return const Icon(Icons.folder_zip_rounded, color: Colors.amber, size: 32);
      case 'apk':
        return const Icon(Icons.android_rounded, color: Colors.lightGreen, size: 32);
      default:
        return const Icon(Icons.insert_drive_file_rounded, color: ChatTheme.primary, size: 32);
    }
  }

  String _docTypeLabel(String fileName) {
    final ext = fileName.split('.').last.toUpperCase();
    return ext.length <= 5 ? '$ext File' : 'Document';
  }

  Widget _buildReactionBadge(MessageModel message, bool isMe) {
    if (message.reactions.isEmpty) return const SizedBox();
    final reaction = message.reactions.values.isNotEmpty ? message.reactions.values.first : null;
    if (reaction == null || reaction.isEmpty) return const SizedBox();

    return Positioned(
      bottom: -15, right: isMe ? 10 : null, left: isMe ? null : 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: ChatTheme.surface, 
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12)
        ),
        child: Text(reaction, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildImageContent(MessageModel message) {
    return Stack(
      children: [
        InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(url: message.mediaUrl!))),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildChatImage(message.mediaUrl!, width: 220),
          ),
        ),
        if (!message.isDeleted)
          Positioned(
            top: 8, right: 8,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              radius: 16,
              child: IconButton(
                icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                onPressed: () => _downloadFile(message.mediaUrl!, 'img_${message.messageId}.jpg'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChatImage(String url, {double? width}) {
    if (kIsWeb) {
      // Use a real HTML <img> element to bypass the XHR CORS restriction that
      // Flutter web's Image.network triggers via dart:html HttpRequest.
      return buildWebHtmlImage(url, width: width, height: 200, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      fit: BoxFit.cover,
      placeholder: (context, _) => Container(
        width: width,
        height: 150,
        color: Colors.white12,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, _, __) => Container(
        width: width,
        height: 150,
        color: Colors.white12,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image_outlined, color: Colors.white54),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () async {
                if (isPlaying) {
                  await _audioPlayer.pause();
                } else if (isPaused) {
                  await _audioPlayer.resume();
                } else {
                  setState(() {
                    _playingMessageId = message.messageId;
                    _audioPosition = Duration.zero;
                  });
                  await _audioPlayer.play(UrlSource(message.mediaUrl!));
                }
              },
              icon: Icon(
                isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                color: Colors.blueAccent,
                size: 42,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 150,
                  height: 20,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                      activeTrackColor: Colors.blue,
                      inactiveTrackColor: Colors.blue.withOpacity(0.2),
                      thumbColor: Colors.blueAccent,
                    ),
                    child: Slider(
                      value: isThis ? _audioPosition.inMilliseconds.toDouble() : 0.0,
                      max: isThis && _audioDuration.inMilliseconds > 0 
                          ? _audioDuration.inMilliseconds.toDouble() 
                          : 1.0,
                      onChanged: (v) {
                        if (isThis) {
                          _audioPlayer.seek(Duration(milliseconds: v.toInt()));
                        }
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    isThis ? _formatDuration(_audioPosition) : 'Voice Note',
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimestampAndStatus(MessageModel message, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 4, left: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.isEdited) const Text('Edited ', style: TextStyle(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic)),
          Text(
            '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 10, color: Colors.white60),
          ),
          if (isMe && !message.isDeleted) ...[
            const SizedBox(width: 6),
            Icon(
              message.status == MessageStatus.read ? Icons.done_all : (message.status == MessageStatus.delivered ? Icons.done_all : Icons.done),
              size: 15,
              color: message.status == MessageStatus.read ? Colors.blue : Colors.white54,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      decoration: const BoxDecoration(
        color: ChatTheme.background,
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply-to preview bar
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: ChatTheme.surface,
              child: Row(
                children: [
                  const Icon(Icons.reply_rounded, size: 16, color: ChatTheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _replyToMessage!.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
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
                  icon: const Icon(Icons.add_circle_outline_rounded, color: ChatTheme.primary, size: 28),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: ChatTheme.surface,
                      builder: (context) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.camera_alt, color: ChatTheme.primary),
                            title: const Text('Camera'),
                            onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); },
                          ),
                          ListTile(
                            leading: const Icon(Icons.photo, color: ChatTheme.primary),
                            title: const Text('Gallery'),
                            onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); },
                          ),
                          ListTile(
                            leading: const Icon(Icons.description, color: ChatTheme.primary),
                            title: const Text('Document (PDF, Excel, etc.)'),
                            onTap: () { Navigator.pop(context); _pickDocument(); },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (!_isRecordingVoice)
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTypingChanged,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        fillColor: ChatTheme.surface,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                AudioRecorderWidget(
                  onStart: () {
                    setState(() => _isRecordingVoice = true);
                    _chatService.setUserStatus(widget.otherUser.uid, UserChatStatus.recording);
                  },
                  onCancel: () {
                    setState(() => _isRecordingVoice = false);
                    _chatService.setUserStatus(widget.otherUser.uid, UserChatStatus.idle);
                  },
                  onStop: (recording) async {
                    setState(() {
                      _isRecordingVoice = false;
                      _isUploading = true;
                      _uploadProgress = 0.0;
                    });
                    _chatService.setUserStatus(widget.otherUser.uid, UserChatStatus.idle);
                    String? url;
                    if (recording.bytes != null) {
                      url = await _storageService.uploadAudioWeb(recording.bytes!, recording.fileName);
                    } else if (recording.file != null) {
                      url = await _storageService.uploadAudio(recording.file!);
                    }
                    setState(() => _isUploading = false);
                    if (url != null) {
                      _chatService.sendMessage('🎤 Voice Note', widget.otherUser.uid,
                          type: MessageType.audio, mediaUrl: url, fileName: recording.fileName);
                    }
                  },
                ),
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

  // ─── Helper / Utility Methods ───────────────────────────────────────────────

  Widget _buildDateDivider(DateTime date) {
    final now = DateTime.now();
    String label;
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = '${date.day} ${_monthName(date.month)} ${date.year}';
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

  String _monthName(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[(month - 1).clamp(0, 11)];
  }

  String _formatLastSeen(DateTime lastSeen) {
    final diff = DateTime.now().difference(lastSeen);
    if (diff.inMinutes < 2) return 'just now';
    if (diff.inMinutes < 60) return 'seen ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'seen ${diff.inHours}h ago';
    return 'seen ${diff.inDays}d ago';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  IconData _getStatusIcon(MessageStatus status) {
    if (status == MessageStatus.read) return Icons.done_all_rounded; // Read
    if (status == MessageStatus.delivered) return Icons.done_all_rounded; // Delivered
    return Icons.done_rounded; // Sent
  }

  Color _getStatusColor(MessageStatus status) {
    if (status == MessageStatus.read) return Colors.cyanAccent;
    return Colors.black;
  }

  Future<void> _showDatePickerJump() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: ChatTheme.primary,
              onPrimary: Colors.black,
              surface: ChatTheme.surface,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (date != null) {
      final snap = await FirebaseFirestore.instance.collection('chats')
          .doc(ChatService().getChatRoomId(currentUserId, widget.otherUser.uid))
          .collection('messages')
          .where('timestamp', isGreaterThanOrEqualTo: DateTime(date.year, date.month, date.day))
          .where('timestamp', isLessThan: DateTime(date.year, date.month, date.day + 1))
          .orderBy('timestamp', descending: false)
          .limit(1)
          .get();
      
      if (snap.docs.isNotEmpty) {
        _scrollToMessage(snap.docs.first.id);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No messages found for this date.')));
      }
    }
  }

  Widget _buildBlockBanner(String title, {bool canUnblock = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      color: Colors.black45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
          ),
          if (canUnblock) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _chatService.toggleBlockUser(widget.otherUser.uid, true),
              child: const Text('UNBLOCK TO MESSAGE', style: TextStyle(color: ChatTheme.primary)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildConnectionPrompt(String title, String buttonText, VoidCallback onBtnPressed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
      color: Colors.black45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onBtnPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: ChatTheme.primary,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
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
    final Widget content = kIsWeb
        ? buildWebHtmlImage(url, fit: BoxFit.contain)
        : CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            errorWidget: (context, _, __) =>
                const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          );
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white),
      body: Center(child: InteractiveViewer(child: content)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Starred Messages Screen
// ─────────────────────────────────────────────────────────────────────────────
class StarredMessagesScreen extends StatelessWidget {
  final UserModel otherUser;
  const StarredMessagesScreen({super.key, required this.otherUser});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Starred Messages'),
        leading: const BackButton(),
      ),
      body: StreamBuilder<List<MessageModel>>(
        stream: chatService.getStarredMessages(otherUser.uid),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final msgs = snap.data!;
          if (msgs.isEmpty) {
            return const Center(child: Text('No starred messages.', style: TextStyle(color: Colors.white54)));
          }
          msgs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: msgs.length,
            itemBuilder: (context, i) {
              final m = msgs[i];
              final isMe = m.senderId == currentUserId;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: ChatTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 6),
                        Text(isMe ? 'You' : otherUser.name,
                            style: const TextStyle(color: ChatTheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(
                          '${m.timestamp.hour}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(m.text, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Media Gallery Screen (all images shared in chat)
// ─────────────────────────────────────────────────────────────────────────────
class MediaGalleryScreen extends StatelessWidget {
  final UserModel otherUser;
  const MediaGalleryScreen({super.key, required this.otherUser});

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();

    return Scaffold(
      appBar: AppBar(title: Text('Media · ${otherUser.name}')),
      body: StreamBuilder<QuerySnapshot>(
        stream: chatService.getMessages(otherUser.uid, limit: 200),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final images = snap.data!.docs
              .map((d) => MessageModel.fromMap(d.data() as Map<String, dynamic>))
              .where((m) => m.type == MessageType.image && m.mediaUrl != null && !m.isDeleted)
              .toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

          if (images.isEmpty) {
            return const Center(child: Text('No photos shared yet.', style: TextStyle(color: Colors.white54)));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4,
            ),
            itemCount: images.length,
            itemBuilder: (context, i) {
              final url = images[i].mediaUrl!;
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => FullScreenImage(url: url)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? buildWebHtmlImage(url, fit: BoxFit.cover)
                      : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
