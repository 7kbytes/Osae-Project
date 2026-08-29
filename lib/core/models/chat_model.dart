import 'timestamp_helper.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isRead;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isRead = false,
  });

  ChatMessage copyWith({
    String? id,
    String? senderId,
    String? senderName,
    String? text,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String docId) {
    return ChatMessage(
      id: docId,
      senderId: map['senderId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
      timestamp: parseDateTime(map['timestamp']),
      isRead: map['isRead'] ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          senderId == other.senderId &&
          text == other.text;

  @override
  int get hashCode => id.hashCode ^ senderId.hashCode ^ text.hashCode;

  @override
  String toString() =>
      'ChatMessage(id: $id, sender: $senderName, text: $text)';
}

class ChatRoom {
  final String id;
  final String jobId;
  final String jobTitle;
  final String seekerId;
  final String seekerName;
  final String posterId;
  final String posterName;
  final String lastMessage;
  final DateTime updatedAt;

  const ChatRoom({
    required this.id,
    required this.jobId,
    required this.jobTitle,
    required this.seekerId,
    required this.seekerName,
    required this.posterId,
    required this.posterName,
    required this.lastMessage,
    required this.updatedAt,
  });

  ChatRoom copyWith({
    String? id,
    String? jobId,
    String? jobTitle,
    String? seekerId,
    String? seekerName,
    String? posterId,
    String? posterName,
    String? lastMessage,
    DateTime? updatedAt,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      seekerId: seekerId ?? this.seekerId,
      seekerName: seekerName ?? this.seekerName,
      posterId: posterId ?? this.posterId,
      posterName: posterName ?? this.posterName,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'seekerId': seekerId,
      'seekerName': seekerName,
      'posterId': posterId,
      'posterName': posterName,
      'lastMessage': lastMessage,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ChatRoom.fromMap(Map<String, dynamic> map, String docId) {
    return ChatRoom(
      id: docId,
      jobId: map['jobId'] ?? '',
      jobTitle: map['jobTitle'] ?? 'Job Inquiry',
      seekerId: map['seekerId'] ?? '',
      seekerName: map['seekerName'] ?? 'Job Seeker',
      posterId: map['posterId'] ?? '',
      posterName: map['posterName'] ?? 'Employer',
      lastMessage: map['lastMessage'] ?? '',
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatRoom &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          jobId == other.jobId &&
          seekerId == other.seekerId &&
          posterId == other.posterId;

  @override
  int get hashCode =>
      id.hashCode ^ jobId.hashCode ^ seekerId.hashCode ^ posterId.hashCode;

  @override
  String toString() =>
      'ChatRoom(id: $id, jobTitle: $jobTitle, seeker: $seekerName, poster: $posterName)';
}
