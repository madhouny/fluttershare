import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/activity_feed.dart';
import 'package:fluttershare/pages/comments.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:fluttershare/widgets/custom_image.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:animator/animator.dart';


class Post extends StatefulWidget {
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  final dynamic likes;

  Post({this.postId,
        this.ownerId,
        this.username,
        this.location,
        this.description,
        this.mediaUrl,
        this.likes});

  factory Post.fromDocument(DocumentSnapshot doc){
    return Post(
      postId: doc['postId'],
      ownerId: doc['ownerId'],
      username: doc['username'],
      location: doc['location'],
      description: doc['description'],
      mediaUrl: doc['mediaUrl'],
      likes: doc['likes'],
    );
  }

  int getLikeCount(likes){
    // if no likes , return 0
    if( likes == null){
      return 0;
    }
    int count = 0;
    // if the key is explicitly set to true, add a like
    likes.values.forEach((val){
      if(val == true){
        count +=  1;
      }
    });
    return count;
  }

  @override
  _PostState createState() => _PostState(
    postId: this.postId,
    ownerId: this.ownerId,
    username: this.username,
    location: this.location,
    description: this.description,
    mediaUrl: this.mediaUrl,
    likes: this.likes,
    likeCount: getLikeCount(this.likes),
  );
}

class _PostState extends State<Post> {
  final String currentUserId = currentUser?.id;
  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  int likeCount;
  Map likes;
  bool showHeart = false;
  bool isLiked;

  _PostState({this.postId,
    this.ownerId,
    this.username,
    this.location,
    this.description,
    this.mediaUrl,
    this.likes,
    this.likeCount
  });

  buildPostHeader(){
    return FutureBuilder(
      future: usersRef.doc(ownerId).get(),
      builder: (context,snapshot){
        if(!snapshot.hasData){
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        bool isPostOwner = currentUserId == ownerId;
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(user.photoUrl),
            backgroundColor: Colors.grey,
          ),
          title: GestureDetector(
            onTap: () => showProfile(context, profileId: user.id),
            child: Text(
              user.username,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          subtitle: Text(location),
          trailing: isPostOwner ? IconButton(
            onPressed: () => handleDeletePost(context),
            icon: Icon(Icons.more_vert),
          ) : Text(''),
        );
      },
    );
  }

  //Delete Post show Dialog
  handleDeletePost(BuildContext parentContext){
  return showDialog(
      context: parentContext,
      builder: (context){
        return SimpleDialog(title: Text('Remove this post?'),
        children: [
          SimpleDialogOption(
            onPressed: (){
              Navigator.pop(context);
              deletePost();
            },
            child: Text('Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
            ),
          ),
        ],);
      });
  }

  //to delete post , ownerId and currentUserId must be equal
  deletePost() async {
    // delete post itself
    postsRef
    .doc(ownerId)
    .collection('userPosts')
    .doc(postId)
    .get().then((doc){
      if(doc.exists){
        doc.reference.delete();
      }
    });
    // delete uploaded image for the post
    storageRef.child("post_$postId.jpg").delete();
    // delete all activity feed notification
   QuerySnapshot activityFeedSnapshot = await activityFeedRef
      .doc(ownerId)
      .collection("feedItems")
      .where('postId', isEqualTo: postId)
      .get();

    activityFeedSnapshot.docs.forEach((doc) {
      if(doc.exists){
        doc.reference.delete();
      }
    });

    // delete all comments
    QuerySnapshot commentsSnapshot = await commentsRef
    .doc(postId)
    .collection('comments')
    .get();

    commentsSnapshot.docs.forEach((doc) {
      if(doc.exists){
        doc.reference.delete();
      }
    });
  }

  handleLikePost(){
    bool _isLiked = likes[currentUserId] == true;

    if(_isLiked){
      postsRef.doc(ownerId)
      .collection('userPosts')
      .doc(postId)
      .update({'likes.$currentUserId': false});
    removeLikeFromActivityFeed();
      setState(() {
        likeCount -= 1;
        isLiked = false;
        likes[currentUserId] == false;
      });
    }else if(!_isLiked){
      postsRef.doc(ownerId)
          .collection('userPosts')
          .doc(postId)
          .update({'likes.$currentUserId': true});
      addLikeToActivityFeed();
      setState(() {
        likeCount += 1;
        isLiked = true;
        likes[currentUserId] == true;
        showHeart = true;
      });
      Timer(Duration(milliseconds: 500), () {
        setState(() {
          showHeart = false;
        });
      });
    }
  }

  // Adding Liking Notifications to Firestore
  addLikeToActivityFeed(){
    // add a notification tothe postOwner's activity feed
    // only iflike made by OTHER user (to avoid getting notification for our own like)
    bool isNotPostOwner = currentUserId != ownerId;
    if(isNotPostOwner){
      activityFeedRef
          .doc(ownerId).collection('feedItems')
          .doc(postId)
          .setData({
        'type':'like',
        'username':currentUser.username,
        'userId':currentUser.id,
        'userProfileImg':currentUser.photoUrl,
        'postId':postId,
        'mediaUrl':mediaUrl,
        'timestamp':timestamps,
    });
  }
  }

  // Remove like notification from Firestore
  removeLikeFromActivityFeed(){
    bool isNotPostOwner = currentUserId != ownerId;
    if(isNotPostOwner){
      activityFeedRef
          .doc(ownerId).collection('feedItems')
          .doc(postId)
          .get().then((doc){
        if(doc.exists){
          doc.reference.delete();
        }
    });
  }}

  buildPostImage(){
    return GestureDetector(
      onDoubleTap: handleLikePost,
      child: Stack(
        alignment: Alignment.center,
        children: [
          cachedNetworkImage(mediaUrl),
        showHeart
          ?Animator(
           duration: Duration(milliseconds: 300),
             tween: Tween(begin:0.8, end: 1.4),
             curve: Curves.elasticOut,
             cycles: 0,
             builder: (anim) => Transform.scale(
               scale: anim.value,
               child: Icon(
                 Icons.favorite,
                 size: 80.0,
                 color:Colors.red,
             ),
           ),
         ):Text(''),
         // showHeart ? Icon(Icons.favorite, size: 80.0, color:
         // Colors.red,) : Text(''),
        ],
      ),
    );
  }

  buildPostFooter(){
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(padding: EdgeInsets.only(top: 40.0, left: 20.0),),
            GestureDetector(
              onTap: handleLikePost,
              child: Icon(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border,
                size: 28.0,
                color: Colors.pink,
              ),
            ),
            Padding(padding: EdgeInsets.only(right: 20.0)),
            GestureDetector(
              onTap: () => showComments(
                context,
                postId: postId,
                ownerId: ownerId,
                mediaUrl: mediaUrl
              ),
              child: Icon(
                Icons.chat,
                size: 28.0,
                color: Colors.blue[900],
              ),
            ),
          ],
        ),
        Row(
          children: [
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                "$likeCount likes",
                style: TextStyle(color: Colors.black,
                fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                "$username ",
                style: TextStyle(color: Colors.black,
                    fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: Text(description)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    isLiked = (likes[currentUserId] == true);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        buildPostHeader(),
        buildPostImage(),
        buildPostFooter(),
      ],
    );
  }
}

showComments(BuildContext context, {String postId, String ownerId,
String mediaUrl }){
  Navigator.push(context, MaterialPageRoute(builder: (context){
   return Comments(
    postId: postId,
    postOwnerId: ownerId,
    postMediaUrl: mediaUrl,
   );
  }
  ));
}
