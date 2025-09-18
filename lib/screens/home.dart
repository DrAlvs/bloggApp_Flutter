import 'package:firebase_course/models/post.dart';
import 'package:flutter/material.dart';
import 'add_post.dart';
import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_course/screens/viewPost.dart';
import 'package:firebase_course/screens/login_screen.dart';
import 'package:firebase_course/screens/profile_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'dart:async';
import 'package:firebase_course/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  String nodeName = "posts";
  List<Post> postsList = <Post>[];
  final AuthService _authService = AuthService();
  bool _isAdmin = false;

  // Stream subscriptions
  StreamSubscription<DatabaseEvent>? _childAddedSubscription;
  StreamSubscription<DatabaseEvent>? _childRemovedSubscription;
  StreamSubscription<DatabaseEvent>? _childChangedSubscription;

  @override
  void initState() {
    super.initState();
    _childAddedSubscription =
        _database.ref(nodeName).onChildAdded.listen(_childAdded);
    _childRemovedSubscription =
        _database.ref(nodeName).onChildRemoved.listen(_childRemoves);
    _childChangedSubscription =
        _database.ref(nodeName).onChildChanged.listen(_childChanged);

    // Fetch role once on init
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final isAdmin = await _authService.isCurrentUserAdmin();
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions
    _childAddedSubscription?.cancel();
    _childRemovedSubscription?.cancel();
    _childChangedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Home",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(
            Icons.person,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              // Show logout confirmation dialog
              final parentContext = context;
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          try {
                            await FirebaseAuth.instance.signOut();
                            print('User signed out successfully');
                            // Navigate to login and clear stack
                            if (mounted) {
                              Navigator.of(parentContext).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) => const LoginScreen()),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            print('Error signing out: $e');
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text('Error signing out: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          // Debug button for testing
          IconButton(
            icon: const Icon(Icons.bug_report, color: Colors.orange),
            onPressed: () async {
              // Force logout for testing
              try {
                await FirebaseAuth.instance.signOut();
                print('Force logout successful');
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                        builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Force logged out for testing'),
                    backgroundColor: Colors.orange,
                  ),
                );
              } catch (e) {
                print('Error in force logout: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error in force logout: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
          // Check auth state button
          IconButton(
            icon: const Icon(Icons.info, color: Colors.green),
            onPressed: () {
              final currentUser = FirebaseAuth.instance.currentUser;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('Current user: ${currentUser?.email ?? 'No user'}'),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
        ],
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: <Widget>[
            Visibility(
              visible: postsList.isEmpty,
              child: const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.article_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        "No posts yet",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Create your first post!",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Visibility(
              visible: postsList.isNotEmpty,
              child: Expanded(
                child: FirebaseAnimatedList(
                  query: _database.ref('posts'),
                  itemBuilder: (_, DataSnapshot snap,
                      Animation<double> animation, int index) {
                    final post = Post.fromSnapshot(snap);
                    return _buildTweetCard(post, animation);
                  },
                ),
              ),
            )
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => const AddPost()));
        },
        backgroundColor: Colors.blue,
        tooltip: "Create a post",
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildTweetCard(Post post, Animation<double> animation) {
    // Get current user
    final currentUser = FirebaseAuth.instance.currentUser;
    final isPostCreator = currentUser?.uid == post.userId;
    final canManage = isPostCreator || _isAdmin;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      )),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with user info and time
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.blue,
                    radius: 20,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.userName.isNotEmpty ? post.userName : 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          timeago.format(
                            DateTime.fromMillisecondsSinceEpoch(post.date),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Show edit/delete for owner or admin
                  if (canManage)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteDialog(post);
                        } else if (value == 'edit') {
                          _showEditDialog(post);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Post content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostView(post),
                    ),
                  );
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.title.isNotEmpty) ...[
                      Text(
                        post.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      post.body,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                    // Display image if available
                    if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          post.imageUrl!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: double.infinity,
                              height: 200,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.error_outline,
                                  color: Colors.grey,
                                  size: 48,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Comment button
                  _buildActionButton(
                    icon: Icons.chat_bubble_outline,
                    label: '${post.commentCount}',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostView(
                            post,
                            showCommentBox: true,
                          ),
                        ),
                      );
                    },
                  ),
                  // Retweet/Share button
                  _buildActionButton(
                    icon: Icons.repeat,
                    label: '0',
                    onTap: () {
                      _showRetweetDialog(post);
                    },
                  ),
                  // Like button
                  _buildActionButton(
                    icon: post.likes.contains(currentUser?.uid)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    label: '${post.likes.length}',
                    color: post.likes.contains(currentUser?.uid)
                        ? Colors.red
                        : null,
                    onTap: () {
                      _toggleLike(post);
                    },
                  ),
                  // Share button
                  _buildActionButton(
                    icon: Icons.share,
                    label: '',
                    onTap: () {
                      _showShareDialog(post);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? Colors.grey[600],
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: color ?? Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showDeleteDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (post.key != null) {
                    await _database.ref(nodeName).child(post.key!).remove();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  Navigator.of(context).pop();
                } catch (e) {
                  print('Error deleting post: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting post: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditDialog(Post post) {
    final titleController = TextEditingController(text: post.title);
    final bodyController = TextEditingController(text: post.body);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Post'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: bodyController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  if (post.key != null) {
                    await _database.ref(nodeName).child(post.key!).update({
                      'title': titleController.text,
                      'body': bodyController.text,
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Post updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  Navigator.of(context).pop();
                } catch (e) {
                  print('Error updating post: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating post: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleLike(Post post) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userId = currentUser.uid;
    final newLikes = List<String>.from(post.likes);

    if (newLikes.contains(userId)) {
      newLikes.remove(userId);
    } else {
      newLikes.add(userId);
    }

    if (post.key != null) {
      _database.ref(nodeName).child(post.key!).update({
        'likes': newLikes,
      });
    }
  }

  void _showCommentDialog(Post post) {
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Comment'),
          content: TextField(
            controller: commentController,
            decoration: const InputDecoration(
              labelText: 'Comment',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (commentController.text.isNotEmpty && post.key != null) {
                  // Increment comment count
                  _database.ref(nodeName).child(post.key!).update({
                    'comments': post.commentCount + 1,
                  });
                }
                Navigator.of(context).pop();
              },
              child: const Text(
                'Post',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRetweetDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Retweet'),
          content: Text('Retweet "${post.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement retweet functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Retweeted!')),
                );
                Navigator.of(context).pop();
              },
              child: const Text(
                'Retweet',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showShareDialog(Post post) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Share Post'),
          content: Text('Share "${post.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement share functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shared!')),
                );
                Navigator.of(context).pop();
              },
              child: const Text(
                'Share',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  _childAdded(DatabaseEvent event) {
    if (mounted) {
      setState(() {
        postsList.add(Post.fromSnapshot(event.snapshot));
      });
    }
  }

  void _childRemoves(DatabaseEvent event) {
    if (mounted) {
      setState(() {
        final beforeLength = postsList.length;
        postsList.removeWhere((post) => post.key == event.snapshot.key);
        final removedCount = beforeLength - postsList.length;
        if (removedCount == 0) {
          print('Post not found for removal: ${event.snapshot.key}');
        }
      });
    }
  }

  void _childChanged(DatabaseEvent event) {
    if (mounted) {
      setState(() {
        final index = postsList.indexWhere((p) => p.key == event.snapshot.key);
        if (index >= 0 && index < postsList.length) {
          postsList[index] = Post.fromSnapshot(event.snapshot);
        } else {
          print('Post not found for update: ${event.snapshot.key}');
          postsList.add(Post.fromSnapshot(event.snapshot));
        }
      });
    }
  }
}
