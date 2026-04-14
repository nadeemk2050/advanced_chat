class UserModel {
  final String uid;
  final String name;
  final String email;
  final String profilePic;
  final bool isOnline;
  final DateTime lastSeen;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.profilePic = '',
    this.isOnline = false,
    required this.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'profilePic': profilePic,
      'isOnline': isOnline,
      'lastSeen': lastSeen.millisecondsSinceEpoch,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      profilePic: map['profilePic'] ?? '',
      isOnline: map['isOnline'] ?? false,
      lastSeen: DateTime.fromMillisecondsSinceEpoch(map['lastSeen'] ?? 0),
    );
  }
}

enum MessageType { text, image, audio }
enum MessageStatus { sent, delivered, read }

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final MessageType type;
  final DateTime timestamp;
  final MessageStatus status;
  final List<String> reactions;
  final String? mediaUrl;

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.type = MessageType.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.reactions = const [],
    this.mediaUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'text': text,
      'type': type.index,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'status': status.index,
      'reactions': reactions,
      'mediaUrl': mediaUrl,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      type: MessageType.values[map['type'] ?? 0],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] ?? 0),
      status: MessageStatus.values[map['status'] ?? 0],
      reactions: List<String>.from(map['reactions'] ?? []),
      mediaUrl: map['mediaUrl'],
    );
  }
}
