import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get postsCollection =>
      _firestore.collection('posts');

  Future<DocumentReference<Map<String, dynamic>>> addPost(
      Map<String, dynamic> post) async {
    return await postsCollection.add(post);
  }

  Future<void> updatePost(String docId, Map<String, dynamic> data) async {
    await postsCollection.doc(docId).update(data);
  }

  Future<void> deletePost(String docId) async {
    await postsCollection.doc(docId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamPosts({
    int? limit,
    String orderByField = 'date',
    bool descending = true,
  }) {
    Query<Map<String, dynamic>> query = postsCollection.orderBy(
      orderByField,
      descending: descending,
    );
    if (limit != null) {
      query = query.limit(limit);
    }
    return query.snapshots();
  }
}


