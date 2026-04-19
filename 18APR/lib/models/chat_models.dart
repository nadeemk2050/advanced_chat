import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, audio, document, ring }
enum MessageStatus { sent, delivered, read }
enum UserChatStatus { idle, typing, recording }
enum ConnectionStatus { none, pending, accepted, unfriendedBySender, unfriendedByReceiver }

class UserModel {
  final String uid;
  final String name;
  final String nameLowercase; // Added
  final String email;
  final bool isOnline;
  final String photoUrl;
  final DateTime lastSeen;
  final List<String> blockedUsers;
  final bool isVisibleInMembersList;

  UserModel({
    required this.uid,
    required this.name,
    required this.nameLowercase,
    required this.email,
    required this.photoUrl,
    required this.isOnline,
    required this.lastSeen,
    required this.blockedUsers,
    this.isVisibleInMembersList = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'nameLowercase': nameLowercase,
      'email': email,
      'photoUrl': photoUrl,
      'isOnline': isOnline,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
      'blockedUsers': blockedUsers,
      'isVisibleInMembersList': isVisibleInMembersList,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      nameLowercase: map['nameLowercase'] ?? (map['name']?.toString().toLowerCase() ?? ''),
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: _parseTimestamp(map['lastSeen']),
      blockedUsers: List<String>.from(map['blockedUsers'] ?? []),
      isVisibleInMembersList: map['isVisibleInMembersList'] ?? true,
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class MessageModel {
  final String messageId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final String? mediaUrl;
  final String? fileName;
  final MessageStatus status;
  final Map<String, String> reactions;
  final bool isDeleted;
  final bool isEdited;
  final bool isStarred;
  final String? replyToMessageId;
  final String? replyToText;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.mediaUrl,
    this.fileName,
    this.status = MessageStatus.sent,
    this.reactions = const {},
    this.isDeleted = false,
    this.isEdited = false,
    this.isStarred = false,
    this.replyToMessageId,
    this.replyToText,
  });

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'type': type.index,
      'mediaUrl': mediaUrl,
      'fileName': fileName,
      'status': status.index,
      'reactions': reactions,
      'isDeleted': isDeleted,
      'isEdited': isEdited,
      'isStarred': isStarred,
      'replyToMessageId': replyToMessageId,
      'replyToText': replyToText,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: _parseTimestamp(map['timestamp']),
      type: _parseMessageType(map['type']),
      mediaUrl: map['mediaUrl'],
      fileName: map['fileName'],
      status: _parseMessageStatus(map['status']),
      reactions: _parseReactions(map['reactions']),
      isDeleted: map['isDeleted'] ?? false,
      isEdited: map['isEdited'] ?? false,
      isStarred: map['isStarred'] ?? false,
      replyToMessageId: map['replyToMessageId'],
      replyToText: map['replyToText'],
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static MessageType _parseMessageType(dynamic value) {
    final int index = value is int ? value : int.tryParse('$value') ?? 0;
    if (index < 0 || index >= MessageType.values.length) {
      return MessageType.text;
    }
    return MessageType.values[index];
  }

  static MessageStatus _parseMessageStatus(dynamic value) {
    final int index = value is int ? value : int.tryParse('$value') ?? 0;
    if (index < 0 || index >= MessageStatus.values.length) {
      return MessageStatus.sent;
    }
    return MessageStatus.values[index];
  }

  static Map<String, String> _parseReactions(dynamic value) {
    if (value is Map) {
      return value.map(
        (key, reaction) => MapEntry(key.toString(), reaction.toString()),
      );
    }

    // Some legacy documents store reactions as an array on web. Ignore invalid
    // shapes instead of crashing the message stream.
    return const {};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group Model
// ─────────────────────────────────────────────────────────────────────────────

class GroupModel {
  final String groupId;
  final String name;
  final List<String> members;
  final String? lastMessage;
  final DateTime lastMessageAt;
  final String? groupPhotoUrl;
  final String createdBy;

  GroupModel({
    required this.groupId,
    required this.name,
    required this.members,
    this.lastMessage,
    required this.lastMessageAt,
    this.groupPhotoUrl,
    required this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'name': name,
      'members': members,
      'lastMessage': lastMessage,
      'lastMessageAt': lastMessageAt,
      'groupPhotoUrl': groupPhotoUrl,
      'createdBy': createdBy,
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map) {
    return GroupModel(
      groupId: map['groupId'] ?? map['id'] ?? '',
      name: map['name'] ?? 'Group',
      members: List<String>.from(map['members'] ?? []),
      lastMessage: map['lastMessage'],
      lastMessageAt: _parseTimestamp(map['lastMessageAt'] ?? map['timestamp']),
      groupPhotoUrl: map['groupPhotoUrl'],
      createdBy: map['createdBy'] ?? '',
    );
  }

  static DateTime _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class ConnectionModel {
  final String senderId;
  final String receiverId;
  final ConnectionStatus status;
  final DateTime updatedAt;

  ConnectionModel({
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'status': status.index,
      'updatedAt': updatedAt,
    };
  }

  factory ConnectionModel.fromMap(Map<String, dynamic> map) {
    return ConnectionModel(
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      status: ConnectionStatus.values[map['status'] ?? 0],
      updatedAt: _parseAnyTimestamp(map['updatedAt']),
    );
  }

  static DateTime _parseAnyTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return DateTime.now();
  }
}
