import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:firebase_course/models/post.dart';
import 'package:firebase_course/models/user_model.dart';
import 'package:firebase_course/services/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
          bottom: const TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(text: 'Posts'),
              Tab(text: 'Account'),
            ],
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Colors.blue,
                    backgroundImage: (user?.photoURL != null)
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: (user?.photoURL == null)
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 32)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? user?.email ?? 'User',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  children: [
                    // Posts tab
                    _UserPostsList(userId: user?.uid),
                    // Account tab
                    _AccountSettings(onEditDisplayName: () async {
                      await _showEditDisplayNameDialog(context);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showEditDisplayNameDialog(BuildContext context) async {
    final controller = TextEditingController(
        text: FirebaseAuth.instance.currentUser?.displayName ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Cannot be empty';
              if (v.trim().length < 2) return 'Too short';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await FirebaseAuth.instance.currentUser
                    ?.updateDisplayName(controller.text.trim());
                await FirebaseAuth.instance.currentUser?.reload();
                // ignore: use_build_context_synchronously
                Navigator.of(ctx).pop();
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Display name updated'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _AccountSettings extends StatelessWidget {
  final Future<void> Function() onEditDisplayName;
  const _AccountSettings({required this.onEditDisplayName});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Not signed in'));
    }

    final DatabaseReference ref =
        FirebaseDatabase.instance.ref('users/${user.uid}');

    return StreamBuilder<DatabaseEvent>(
      stream: ref.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final data = snapshot.data?.snapshot.value;
        final UserModel? profile = (data is Map)
            ? UserModel.fromMap(Map<String, dynamic>.from(data as Map))
            : null;

        return ListView(
          children: [
            const Text(
              'Account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show details on my profile'),
              subtitle: const Text('Toggle visibility of school and address'),
              secondary: const Icon(Icons.visibility_outlined),
              value: profile?.showDetails ?? true,
              onChanged: (val) async {
                await AuthService().updateUserProfile(user.uid, {
                  'showDetails': val,
                });
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: const Text('Display Name'),
              subtitle: Text(user.displayName ?? 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                await onEditDisplayName();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              subtitle: Text(user.email ?? ''),
            ),
            const SizedBox(height: 24),
            const Text(
              'Profile Details',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school_outlined),
              title: const Text('School'),
              subtitle: Text(profile?.school?.trim().isNotEmpty == true
                  ? profile!.school!
                  : 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                await _editField(context,
                    title: 'Edit School',
                    label: 'School',
                    initialValue: profile?.school ?? '', onSave: (value) async {
                  await AuthService().updateUserProfile(user.uid, {
                    'school': value.trim(),
                  });
                });
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.home_outlined),
              title: const Text('Address'),
              subtitle: Text(profile?.address?.trim().isNotEmpty == true
                  ? profile!.address!
                  : 'Not set'),
              trailing: const Icon(Icons.edit),
              onTap: () async {
                await _editField(context,
                    title: 'Edit Address',
                    label: 'Address',
                    initialValue: profile?.address ?? '',
                    onSave: (value) async {
                  await AuthService().updateUserProfile(user.uid, {
                    'address': value.trim(),
                  });
                });
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _editField(BuildContext context,
      {required String title,
      required String label,
      required String initialValue,
      required Future<void> Function(String value) onSave}) async {
    final controller = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null) return null;
              if (v.trim().length > 200) return 'Too long';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                await onSave(controller.text);
                // ignore: use_build_context_synchronously
                Navigator.of(ctx).pop();
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Saved'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _UserPostsList extends StatelessWidget {
  final String? userId;
  const _UserPostsList({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) {
      return const Center(child: Text('Not signed in'));
    }

    final Query query = FirebaseDatabase.instance
        .ref('posts')
        .orderByChild(Post.USER_ID)
        .equalTo(userId);

    return StreamBuilder<DatabaseEvent>(
      stream: query.onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final dataSnapshot = snapshot.data?.snapshot;
        if (dataSnapshot == null || dataSnapshot.value == null) {
          return const Center(child: Text('No posts yet'));
        }

        final List<Post> posts = [];
        for (final child in dataSnapshot.children) {
          posts.add(Post.fromSnapshot(child));
        }

        posts.sort((a, b) => b.date.compareTo(a.date));

        return ListView.separated(
          itemCount: posts.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final post = posts[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage:
                    (post.userAvatar != null && post.userAvatar!.isNotEmpty)
                        ? NetworkImage(post.userAvatar!)
                        : null,
                child: (post.userAvatar == null || post.userAvatar!.isEmpty)
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(post.title),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeago.format(
                        DateTime.fromMillisecondsSinceEpoch(post.date),
                        allowFromNow: true),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              trailing: (post.imageUrl != null && post.imageUrl!.isNotEmpty)
                  ? const Icon(Icons.image, color: Colors.grey)
                  : null,
              onTap: () {
                // Optionally navigate to a detailed view if available
              },
            );
          },
        );
      },
    );
  }
}
