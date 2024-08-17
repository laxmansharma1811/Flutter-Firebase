import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'home_page.dart'; // Make sure to import the homepage

class EditPostScreen extends StatefulWidget {
  final String postId;
  final String currentTitle;
  final String currentDescription;
  final VoidCallback onPostEdited;

  EditPostScreen({
    required this.postId,
    required this.currentTitle,
    required this.currentDescription,
    required this.onPostEdited,
  });

  @override
  _EditPostScreenState createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentTitle);
    _descriptionController = TextEditingController(text: widget.currentDescription);
  }

  Future<void> _updatePost() async {
    try {
      await _firestore.collection('posts').doc(widget.postId).update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      widget.onPostEdited();

      // Navigate back to the homepage, removing all previous routes
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => HomePage()),
        (route) => false,
      );
    } catch (error) {
      // Handle any errors here, e.g., show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update post')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Post'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: 5,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _updatePost,
              child: Text('Update Post'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
