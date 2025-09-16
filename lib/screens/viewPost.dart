import 'package:firebase_course/models/post.dart';
import 'package:firebase_course/screens/edit_post.dart';
import 'package:flutter/material.dart';
import '../db/post_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class PostView extends StatefulWidget {
  final Post post;
  final bool showCommentBox;

  const PostView(this.post, {super.key, this.showCommentBox = false});

  @override
  _PostViewState createState() => _PostViewState();
}

class _PostViewState extends State<PostView> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  bool _showCommentBox = false;

  @override
  void initState() {
    super.initState();
    _showCommentBox = widget.showCommentBox;
    if (_showCommentBox) {
      // Delay focus to after first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _commentFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post.title),
      ),
      body: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Text(
                    timeago.format(DateTime.fromMillisecondsSinceEpoch(widget.post.date)),
                    style: const TextStyle(fontSize: 14.0, color: Colors.grey),
                  ),
                ),),
              IconButton(icon: const Icon(Icons.delete),
              onPressed: (){
                PostService postService = PostService(widget.post.toMap());
                postService.deletePost();
                Navigator.pop(context);

              },),
              IconButton(icon: const Icon(Icons.edit),
                onPressed: (){
                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => EditPost(widget.post)));
                },),
            ],
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(widget.post.body),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Comments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: _CommentsList(postKey: widget.post.key),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _showCommentBox
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _CommentInput(
              controller: _commentController,
              focusNode: _commentFocusNode,
              onSend: () => _handleSendComment(),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: const Text('Add a comment'),
                      onPressed: () {
                        setState(() {
                          _showCommentBox = true;
                        });
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _commentFocusNode.requestFocus();
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSendComment() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || widget.post.key == null) return;
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    try {
      final DatabaseReference commentsRef = FirebaseDatabase.instance
          .ref('posts/${widget.post.key}/comments');

      await commentsRef.push().set({
        'text': text,
        'userId': currentUser.uid,
        'userName': currentUser.displayName ?? (currentUser.email ?? 'User'),
        'userAvatar': currentUser.photoURL,
        'timestamp': ServerValue.timestamp,
      });

      // Optionally update aggregate comment count on the post
      if (widget.post.key != null) {
        final DatabaseReference postRef =
            FirebaseDatabase.instance.ref('posts/${widget.post.key}');
        final int newCount = (widget.post.commentCount) + 1;
        await postRef.update({'comments': newCount});
      }

      _commentController.clear();
      setState(() {
        _showCommentBox = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment posted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e')),
      );
    }
  }
}

class _CommentsList extends StatelessWidget {
  final String? postKey;
  const _CommentsList({required this.postKey});

  @override
  Widget build(BuildContext context) {
    if (postKey == null) {
      return const Center(child: Text('Unable to load comments'));
    }

    final Query query = FirebaseDatabase.instance
        .ref('posts/$postKey/comments')
        .orderByChild('timestamp');

    return StreamBuilder<DatabaseEvent>(
      stream: query.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final snap = snapshot.data?.snapshot;
        if (snap == null || snap.value == null) {
          return const Center(child: Text('No comments yet'));
        }

        final comments = <Map<String, dynamic>>[];
        for (final child in snap.children) {
          final value = child.value;
          if (value is Map) {
            comments.add({
              'key': child.key,
              'text': value['text'] ?? '',
              'userId': value['userId'] ?? '',
              'userName': value['userName'] ?? 'User',
              'userAvatar': value['userAvatar'],
              'timestamp': value['timestamp'] ?? 0,
            });
          }
        }

        comments.sort((a, b) => (a['timestamp'] as int)
            .compareTo((b['timestamp'] as int)));

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: comments.length,
          separatorBuilder: (_, __) => const Divider(height: 16),
          itemBuilder: (context, index) {
            final c = comments[index];
            final ts = c['timestamp'] is int
                ? DateTime.fromMillisecondsSinceEpoch(c['timestamp'] as int)
                : DateTime.now();
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: (c['userAvatar'] != null &&
                          (c['userAvatar'] as String).isNotEmpty)
                      ? NetworkImage(c['userAvatar'] as String)
                      : null,
                  child: (c['userAvatar'] == null ||
                          (c['userAvatar'] as String?)?.isEmpty == true)
                      ? const Icon(Icons.person, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c['userName'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(
                            timeago.format(ts, allowFromNow: true),
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(c['text'] as String),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CommentInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _CommentInput({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: const BoxDecoration(),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                hintText: 'Write a comment...',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send, color: Colors.blue),
            onPressed: onSend,
          ),
        ],
      ),
    );
  }
}
