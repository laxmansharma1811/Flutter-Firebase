import 'package:blog_app/screens/add_post_screen.dart';
import 'package:blog_app/screens/change_password_screen.dart';
import 'package:blog_app/screens/edit_post_screen.dart';
import 'package:blog_app/screens/edit_profile_screen.dart';
import 'package:blog_app/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentIndex = 0;

  Future<void> _deletePost(String postId) async {
    try {
      await _firestore.collection('posts').doc(postId).delete();
    } catch (e) {
      print("Error deleting post: $e");
    }
  }

  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginPage(message: "Logout Successfully")));
  }

  Future<String?> _getUserName(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc['fullName'];
      }
    } catch (e) {
      print("Error getting user name: $e");
    }
    return null;
  }

  Future<void> _toggleLike(String postId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final likesRef = _firestore.collection('posts').doc(postId).collection('likes');
    final userLikeDoc = likesRef.doc(userId);

    final docSnapshot = await userLikeDoc.get();
    if (docSnapshot.exists) {
      await userLikeDoc.delete();
    } else {
      await userLikeDoc.set({
        'likedAt': Timestamp.now(),
      });
    }
  }

  Future<bool> _isLiked(String postId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;

    final docSnapshot = await _firestore.collection('posts').doc(postId).collection('likes').doc(userId).get();
    return docSnapshot.exists;
  }

  Future<int> _getLikesCount(String postId) async {
    final likesSnapshot = await _firestore.collection('posts').doc(postId).collection('likes').get();
    return likesSnapshot.size;
  }

  Future<void> _addComment(String postId, String commentText) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || commentText.isEmpty) return;

    await _firestore.collection('posts').doc(postId).collection('comments').add({
      'userId': userId,
      'text': commentText,
      'timestamp': Timestamp.now(),
    });
  }

  Future<void> _addReply(String postId, String commentId, String replyText) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null || replyText.isEmpty) return;

    await _firestore.collection('posts').doc(postId).collection('comments').doc(commentId).collection('replies').add({
      'userId': userId,
      'text': replyText,
      'timestamp': Timestamp.now(),
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text('Blog App'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'changePassword') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChangePasswordScreen()),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'changePassword',
                  child: Text('Change Password'),
                ),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Text('Logout'),
                ),
              ];
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Settings'),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => ChangePasswordScreen()));
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: _getBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Add Blog',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _getBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return AddPostScreen(onPostAdded: () => setState(() {}));
      case 2:
        return _buildProfileContent();
      default:
        return _buildHomeContent();
    }
  }

  Widget _buildHomeContent() {
    return StreamBuilder(
      stream: _firestore.collection('posts').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text('No posts yet.'));
        }
        final posts = snapshot.data!.docs;
        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final postId = post.id;
            final imageUrl = post['imageUrl'] as String?;
            final timestamp = post['timestamp'] as Timestamp?;
            final dateTime = timestamp?.toDate() ?? DateTime.now();
            final formattedDate = DateFormat('MMM d, y - h:mm a').format(dateTime);
            final isCurrentUserPost = post['userId'] == _auth.currentUser?.uid;

            return FutureBuilder<String?>(
              future: _getUserName(post['userId']),
              builder: (context, AsyncSnapshot<String?> userNameSnapshot) {
                if (userNameSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                final userName = userNameSnapshot.data ?? 'Unknown User';

                return FutureBuilder<bool>(
                  future: _isLiked(postId),
                  builder: (context, AsyncSnapshot<bool> likeStatusSnapshot) {
                    if (likeStatusSnapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final isLiked = likeStatusSnapshot.data ?? false;

                    return FutureBuilder<int>(
                      future: _getLikesCount(postId),
                      builder: (context, AsyncSnapshot<int> likeCountSnapshot) {
                        if (likeCountSnapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        final likeCount = likeCountSnapshot.data ?? 0;

                        return Card(
                          margin: EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(post['title']),
                                subtitle: Text('By $userName\n$formattedDate'),
                                trailing: isCurrentUserPost
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.edit),
                                            onPressed: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => EditPostScreen(
                                                    postId: postId,
                                                    currentTitle: post['title'],
                                                    currentDescription: post['description'],
                                                    onPostEdited: () => setState(() {}),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete),
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (BuildContext context) {
                                                  return AlertDialog(
                                                    title: Text("Delete Post"),
                                                    content: Text("Are you sure you want to delete this post?"),
                                                    actions: [
                                                      TextButton(
                                                        child: Text("Cancel"),
                                                        onPressed: () {
                                                          Navigator.of(context).pop();
                                                        },
                                                      ),
                                                      TextButton(
                                                        child: Text("Delete"),
                                                        onPressed: () {
                                                          _deletePost(postId);
                                                          Navigator.of(context).pop();
                                                        },
                                                      ),
                                                    ],
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                              if (imageUrl != null)
                                Image.network(
                                  imageUrl,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(child: Text('Failed to load image'));
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  post['description'],
                                  style: TextStyle(fontSize: 16),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isLiked ? Icons.favorite : Icons.favorite_border,
                                      color: isLiked ? Colors.red : Colors.grey,
                                    ),
                                    onPressed: () async {
                                      await _toggleLike(postId);
                                      setState(() {});
                                    },
                                  ),
                                  Text(
                                    '$likeCount',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Comments:',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    StreamBuilder(
                                      stream: _firestore.collection('posts').doc(postId).collection('comments').orderBy('timestamp').snapshots(),
                                      builder: (context, AsyncSnapshot<QuerySnapshot> commentsSnapshot) {
                                        if (commentsSnapshot.connectionState == ConnectionState.waiting) {
                                          return Center(child: CircularProgressIndicator());
                                        }
                                        if (!commentsSnapshot.hasData || commentsSnapshot.data!.docs.isEmpty) {
                                          return Text('No comments yet.');
                                        }
                                        final comments = commentsSnapshot.data!.docs;
                                        return Column(
                                          children: comments.map((comment) {
                                            final commentId = comment.id;
                                            final commentUserId = comment['userId'];
                                            final commentText = comment['text'];
                                            final commentTimestamp = comment['timestamp'] as Timestamp?;
                                            final commentDateTime = commentTimestamp?.toDate() ?? DateTime.now();
                                            final commentFormattedDate = DateFormat('MMM d, y - h:mm a').format(commentDateTime);

                                            return FutureBuilder<String?>(
                                              future: _getUserName(commentUserId),
                                              builder: (context, AsyncSnapshot<String?> commentUserNameSnapshot) {
                                                if (commentUserNameSnapshot.connectionState == ConnectionState.waiting) {
                                                  return Center(child: CircularProgressIndicator());
                                                }
                                                final commentUserName = commentUserNameSnapshot.data ?? 'Unknown User';

                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    ListTile(
                                                      title: Text(commentUserName),
                                                      subtitle: Text(commentText),
                                                      trailing: IconButton(
                                                        icon: Icon(Icons.reply),
                                                        onPressed: () {
                                                          _showReplyDialog(postId, commentId);
                                                        },
                                                      ),
                                                    ),
                                                    StreamBuilder(
                                                      stream: _firestore.collection('posts').doc(postId).collection('comments').doc(commentId).collection('replies').orderBy('timestamp').snapshots(),
                                                      builder: (context, AsyncSnapshot<QuerySnapshot> repliesSnapshot) {
                                                        if (repliesSnapshot.connectionState == ConnectionState.waiting) {
                                                          return Center(child: CircularProgressIndicator());
                                                        }
                                                        if (!repliesSnapshot.hasData || repliesSnapshot.data!.docs.isEmpty) {
                                                          return SizedBox.shrink();
                                                        }
                                                        final replies = repliesSnapshot.data!.docs;
                                                        return Column(
                                                          children: replies.map((reply) {
                                                            final replyUserId = reply['userId'];
                                                            final replyText = reply['text'];
                                                            final replyTimestamp = reply['timestamp'] as Timestamp?;
                                                            final replyDateTime = replyTimestamp?.toDate() ?? DateTime.now();
                                                            final replyFormattedDate = DateFormat('MMM d, y - h:mm a').format(replyDateTime);

                                                            return FutureBuilder<String?>(
                                                              future: _getUserName(replyUserId),
                                                              builder: (context, AsyncSnapshot<String?> replyUserNameSnapshot) {
                                                                if (replyUserNameSnapshot.connectionState == ConnectionState.waiting) {
                                                                  return Center(child: CircularProgressIndicator());
                                                                }
                                                                final replyUserName = replyUserNameSnapshot.data ?? 'Unknown User';

                                                                return ListTile(
                                                                  title: Text(replyUserName),
                                                                  subtitle: Text(replyText),
                                                                );
                                                              },
                                                            );
                                                          }).toList(),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                );
                                              },
                                            );
                                          }).toList(),
                                        );
                                      },
                                    ),
                                    SizedBox(height: 8),
                                    TextField(
                                      decoration: InputDecoration(
                                        labelText: 'Add a comment',
                                        border: OutlineInputBorder(),
                                      ),
                                      onSubmitted: (value) {
                                        _addComment(postId, value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildProfileContent() {
  final user = FirebaseAuth.instance.currentUser;
  return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
    builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: CircularProgressIndicator());
      }

      if (snapshot.hasError) {
        return Center(child: Text("Something went wrong"));
      }

      if (snapshot.hasData && !snapshot.data!.exists) {
        return Center(child: Text("User profile not found"));
      }

      if (snapshot.connectionState == ConnectionState.done) {
        Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(data['profilePicture'] ?? 'https://via.placeholder.com/150'),
              ),
              SizedBox(height: 20),
              Text(
                data['fullName'] ?? 'Name not set',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                data['email'] ?? 'Email not set',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfileScreen(userData: data),
                    ),
                  );
                  if (result == true) {
                    setState(() {}); // Refresh the profile page
                  }
                },
                child: Text('Edit Profile'),
              ),
            ],
          ),
        );
      }

      return Center(child: Text("Loading..."));
    },
  );
}

  void _showReplyDialog(String postId, String commentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Reply"),
          content: TextField(
            decoration: InputDecoration(
              labelText: 'Write your reply...',
            ),
            onSubmitted: (value) async {
              await _addReply(postId, commentId, value);
              Navigator.of(context).pop();
            },
          ),
          actions: [
            TextButton(
              child: Text("Cancel"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}