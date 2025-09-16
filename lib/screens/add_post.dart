import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/post.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class AddPost extends StatefulWidget {
  const AddPost({super.key});

  @override
  _AddPostState createState() => _AddPostState();
}

class _AddPostState extends State<AddPost> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _database = FirebaseDatabase.instance;
  final _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  double _uploadProgress = 0.0;
  bool _isError = false;
  String _errorMessage = '';
  String? _uploadedImageUrl;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800, // Reduced from 1920
        maxHeight: 600, // Reduced from 1080
        imageQuality: 70, // Reduced from 85
      );
      if (image != null) {
        if (kIsWeb) {
          // For web, read as bytes
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageBytes = null;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error selecting image'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 600,
        imageQuality: 70,
      );
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedImage = null;
          });
        } else {
          setState(() {
            _selectedImage = File(image.path);
            _selectedImageBytes = null;
          });
        }
      }
    } catch (e) {
      print('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error taking photo'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Image'),
          content: const Text('Choose how you want to add an image:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.photo_library),
                  SizedBox(width: 8),
                  Text('Gallery'),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _takePhoto();
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.camera_alt),
                  SizedBox(width: 8),
                  Text('Camera'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> uploadToCloudinary() async {
    if (_selectedImage == null && _selectedImageBytes == null) return null;

    try {
      setState(() {
        _uploadProgress = 0.0;
        _isError = false;
        _errorMessage = '';
      });

      // TODO: Replace with your actual Cloudinary configuration
      const String cloudName = 'drjmafsii';
      const String uploadPreset = 'flutter_bloggapp';

      // Create multipart request
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add upload preset
      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'blog_posts';

      // Add file
      if (kIsWeb && _selectedImageBytes != null) {
        // For web, upload bytes
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          _selectedImageBytes!,
          filename: 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));
      } else if (_selectedImage != null) {
        // For mobile, upload file
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          _selectedImage!.path,
        ));
      } else {
        return null;
      }

      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData);
        _uploadedImageUrl = jsonResponse['secure_url'];

        setState(() {
          _uploadProgress = 1.0;
        });

        print('Image uploaded successfully: $_uploadedImageUrl');
        return _uploadedImageUrl;
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
      setState(() {
        _isError = true;
        _errorMessage = "Image upload failed";
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading image: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _addPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get current user
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to create a post'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Upload image if selected
      String? imageUrl;
      if (_selectedImage != null || _selectedImageBytes != null) {
        imageUrl = await uploadToCloudinary();
        if (imageUrl == null) {
          setState(() => _isLoading = false);
          return; // Stop if image upload failed
        }
      }

      // Create post data with current user info
      Map<String, dynamic> postData = {
        Post.TITLE: _titleController.text.trim(),
        Post.BODY: _bodyController.text.trim(),
        Post.DATE: DateTime.now().millisecondsSinceEpoch,
        Post.USER_ID: currentUser.uid,
        Post.USER_NAME: currentUser.displayName ?? currentUser.email ?? "User",
        Post.USER_AVATAR: currentUser.photoURL,
        Post.LIKES: [],
        Post.COMMENTS: 0,
        Post.IMAGE_URL: imageUrl,
      };

      // Add post to database
      await _database.ref('posts').push().set(postData);

      // Clear form
      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _selectedImage = null;
        _selectedImageBytes = null;
        _uploadProgress = 0.0;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Post created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.pop(context);
    } catch (e) {
      print('Error adding post: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating post: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        color: Colors.grey[50],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image picker
                if (_selectedImage != null || _selectedImageBytes != null) ...[
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[200],
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _selectedImageBytes != null
                              ? Image.memory(
                                  _selectedImageBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 200,
                                )
                              : _selectedImage != null
                                  ? Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 200,
                                    )
                                  : Container(
                                      width: double.infinity,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image,
                                          color: Colors.grey,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImage = null;
                                _selectedImageBytes = null;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Image picker button
                OutlinedButton.icon(
                  onPressed: _showImageSourceDialog,
                  icon: const Icon(Icons.image),
                  label: Text(
                      (_selectedImage != null || _selectedImageBytes != null)
                          ? 'Change Image'
                          : 'Add Image'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '💡 Tip: Images are automatically optimized for faster upload',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Title field
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Title (Optional)',
                    hintText: 'Add a title to your post...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (val) {
                    if (val != null && val.isNotEmpty && val.length > 100) {
                      return "Title cannot have more than 100 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Body field
                TextFormField(
                  controller: _bodyController,
                  maxLines: 8,
                  decoration: InputDecoration(
                    labelText: 'What\'s on your mind?',
                    hintText: 'Share your thoughts, ideas, or experiences...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Colors.blue, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return "Post content cannot be empty";
                    }
                    if (val.length > 1000) {
                      return "Post content cannot have more than 1000 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit button
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _addPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedImage != null ||
                                        _selectedImageBytes != null
                                    ? 'Uploading... ${(_uploadProgress * 100).toStringAsFixed(0)}%'
                                    : 'Creating Post...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                        : const Text(
                            'Create Post',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
