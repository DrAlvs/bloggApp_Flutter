import 'package:firebase_database/firebase_database.dart';

class Post {
  static const KEY = "key";
  static const DATE = "date";
  static const TITLE = "title";
  static const BODY = "body";
  static const USER_ID = "userId";
  static const USER_NAME = "userName";
  static const USER_AVATAR = "userAvatar";
  static const LIKES = "likes";
  static const COMMENTS = "comments";
  static const IMAGE_URL = "imageUrl";

  int date;
  String? key;
  String title;
  String body;
  String userId;
  String userName;
  String? userAvatar;
  List<String> likes;
  int commentCount;
  String? imageUrl;

  Post({
    required this.date,
    required this.title,
    required this.body,
    required this.userId,
    required this.userName,
    this.userAvatar,
    this.likes = const [],
    this.commentCount = 0,
    this.imageUrl,
  });

  Post.fromSnapshot(DataSnapshot snap)
      : key = snap.key,
        date = 0,
        title = "",
        body = "",
        userId = "",
        userName = "",
        userAvatar = null,
        likes = [],
        commentCount = 0,
        imageUrl = null {
    try {
      if (snap.value is Map) {
        Map<dynamic, dynamic> data = snap.value as Map<dynamic, dynamic>;
        body = data[BODY]?.toString() ?? "";
        date = data[DATE] ?? 0;
        title = data[TITLE]?.toString() ?? "";
        userId = data[USER_ID]?.toString() ?? "";
        userName = data[USER_NAME]?.toString() ?? "";
        userAvatar = data[USER_AVATAR]?.toString();
        likes = List<String>.from(data[LIKES] ?? []);
        commentCount = data[COMMENTS] ?? 0;
        imageUrl = data[IMAGE_URL]?.toString();
      } else {
        print("Warning: DataSnapshot value is not a Map: ${snap.value}");
      }
    } catch (e) {
      print("Error parsing Post from snapshot: $e");
    }
  }

  Map toMap() {
    return {
      BODY: body,
      TITLE: title,
      DATE: date,
      KEY: key,
      USER_ID: userId,
      USER_NAME: userName,
      USER_AVATAR: userAvatar,
      LIKES: likes,
      COMMENTS: commentCount,
      IMAGE_URL: imageUrl,
    };
  }

  @override
  String toString() {
    return 'Post{key: $key, title: $title, body: $body, date: $date, userId: $userId, userName: $userName, likes: ${likes.length}, comments: $commentCount}';
  }
}
