import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  EditProfileScreen({required this.userData});

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _imageUrlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userData['fullName']);
    _emailController = TextEditingController(text: widget.userData['email']);
    _imageUrlController = TextEditingController(text: widget.userData['profilePicture']);
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        String userId = FirebaseAuth.instance.currentUser!.uid;

        // Update user data in Firestore
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'fullName': _nameController.text,
          'profilePicture': _imageUrlController.text,
        });

        // Update email in Firebase Auth if it has changed
        if (_emailController.text != widget.userData['email']) {
          await FirebaseAuth.instance.currentUser!.updateEmail(_emailController.text);
          await FirebaseFirestore.instance.collection('users').doc(userId).update({
            'email': _emailController.text,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true); // Pass true to indicate profile was updated
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating profile: $e')),
        );
      }

      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Profile'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(_imageUrlController.text.isNotEmpty 
                  ? _imageUrlController.text 
                  : 'https://via.placeholder.com/150'),
                child: _imageUrlController.text.isEmpty 
                  ? Icon(Icons.person, size: 50, color: Colors.white70)
                  : null,
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _imageUrlController,
                decoration: InputDecoration(labelText: 'Profile Picture URL'),
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    bool validURL = Uri.tryParse(value)?.hasAbsolutePath ?? false;
                    if (!validURL) {
                      return 'Please enter a valid URL';
                    }
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // Refresh the UI to update the CircleAvatar
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _updateProfile,
                child: _isLoading 
                  ? CircularProgressIndicator() 
                  : Text('Update Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }
}