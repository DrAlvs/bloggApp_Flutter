import 'package:firebase_course/db/post_service.dart';
import 'package:firebase_course/models/post.dart';
import 'package:firebase_course/screens/home.dart';
import 'package:flutter/material.dart';

class EditPost extends StatefulWidget {
  final Post post;

  const EditPost(this.post, {super.key});

  @override
  _EditPostState createState() => _EditPostState();
}

class _EditPostState extends State<EditPost> {
  final GlobalKey<FormState> formkey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("edit post"),
        elevation: 0.0,
      ),
      body: Form(
          key: formkey,
          child: ListView(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  initialValue: widget.post.title,
                  decoration: const InputDecoration(
                      labelText: "Post tilte",
                      border: OutlineInputBorder()
                  ),
                  onSaved: (val) => widget.post.title = val ?? "",
                  validator: (val){
                    if(val == null || val.isEmpty ){
                      return "title field cant be empty";
                    }else if(val.length > 16){
                      return "title cannot have more than 16 characters ";
                    }
                    return null;
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextFormField(
                  initialValue: widget.post.body,
                  decoration: const InputDecoration(
                      labelText: "Post body",
                      border: OutlineInputBorder()
                  ),
                  onSaved: (val) => widget.post.body = val ?? "",
                  validator: (val){
                    if(val == null || val.isEmpty){
                      return "body field cant be empty";
                    }
                    return null;
                  },
                ),
              ),
            ],
          )),
      floatingActionButton: FloatingActionButton(onPressed: (){
        insertPost();
//        Navigator.pop(context);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
      },
        backgroundColor: Colors.red,
        tooltip: "exit a post",
        child: const Icon(Icons.edit, color: Colors.white,),),
    );
  }

  void insertPost() {
    final FormState? form = formkey.currentState;
    if(form != null && form.validate()){
      form.save();
      form.reset();
      widget.post.date = DateTime.now().millisecondsSinceEpoch;
      PostService postService = PostService(widget.post.toMap());
      postService.updatePost();
    }
  }


}
