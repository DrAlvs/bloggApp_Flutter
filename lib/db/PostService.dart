//import 'package:firebase_course/models/post.dart';
import 'package:firebase_database/firebase_database.dart';


class PostService{
  String nodeName = "posts";
  FirebaseDatabase database = FirebaseDatabase.instance;
  Map post;

  PostService(this.post);

  addPost(){
//    this is going to give a reference to the posts node
   database.ref(nodeName).push().set(post);
  }

  deletePost(){
    database.ref('$nodeName/${post['key']}').remove();
  }

  updatePost(){
    database.ref('$nodeName/${post['key']}').update(
      {"title": post['title'], "body": post['body'], "date":post['date']}
    );
  }
}