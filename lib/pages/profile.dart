import 'package:flutter/material.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/edit_profile.dart';
import 'package:fluttershare/pages/home.dart';
import 'package:fluttershare/widgets/header.dart';
import 'package:fluttershare/widgets/post.dart';
import 'package:fluttershare/widgets/post_tile.dart';
import 'package:fluttershare/widgets/progress.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_svg/svg.dart';

class Profile extends StatefulWidget {
  final String profileId;

  Profile({this.profileId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {

  final String currentUserId = currentUser?.id;
  String postOrientation = 'grid';
  bool isLoading = false;
  bool isFollowing = false;
  int followerCount = 0;
  int followingCount = 0;
  int postCount = 0;
  List<Post> posts = [];

  @override
  void initState(){
    super.initState();
    getProfilePosts();
    getFollowers();
    getFollowing();
    checkIfFollowing();
  }

  checkIfFollowing() async {
   DocumentSnapshot doc =  await followersRef
          .doc(widget.profileId)
          .collection('userFollowers')
          .doc(currentUserId)
          .get();
    setState(() {
      isFollowing = doc.exists;
    });
  }

  getFollowers() async {
    QuerySnapshot snapshot =  await followersRef
        .doc(widget.profileId)
        .collection('userFollowers')
        .get();
    setState(() {
      followerCount = snapshot.docs.length;
    });
  }

  getFollowing() async {
    QuerySnapshot snapshot =  await followingRef
        .doc(widget.profileId)
        .collection('userFollowing')
        .get();
    setState(() {
      followingCount = snapshot.docs.length;
    });
  }

  getProfilePosts() async {
    setState(() {
      isLoading = true;
    });
    QuerySnapshot snapshot = await postsRef.doc(widget.profileId).collection('userPosts').
    orderBy('timestamp', descending: true).get();

    setState(() {
      isLoading = false;
      postCount = snapshot.docs.length;
      posts = snapshot.docs.map((doc) => Post.fromDocument(doc)).toList();
    });
  }

  Column buildCountColumn(String label, int count){
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
          Text(
            count.toString(),
            style: TextStyle(fontSize: 22.0,fontWeight: FontWeight.bold),
          ),
        Container(
          margin: EdgeInsets.only(top: 4.0),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 15.0,
              fontWeight: FontWeight.w400,
            ),
          ),
        )
      ],
    );
  }

  //Edit Profil
  editProfile(){
    Navigator.push(context, MaterialPageRoute(builder: (context)=>
    EditProfile(currentUserId: currentUserId)));
  }

  //To Manage Edit , follow or unfollow Actions
  Container buildButton({String text, Function function}){
    return Container(
      padding: EdgeInsets.only(top: 2.0),
      child: FlatButton(
        onPressed: function,
        child: Container(
          width: 250.0,
          height: 27.0,
          child: Text(
            text,
            style: TextStyle(
              color: isFollowing ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isFollowing ? Colors.white : Colors.blue,
            border: Border.all(
              color: isFollowing ? Colors.grey : Colors.blue,
            ),
            borderRadius: BorderRadius.circular(5.0),
          ),
        ),
      ),
    );
  }

  buildProfilButton(){
    // veiwing your own profile , we should show edit profile button
    bool isProfileOwner  = currentUserId == widget.profileId;
    if(isProfileOwner){
      return buildButton(
        text: "Edit Profile",
        function:editProfile,
      );
    }else if(isFollowing) {
      return buildButton(
        text: "Unfollow",
        function: handleUnfollowUser,
      );
    }else if(!isFollowing){
      return buildButton(
        text: "Follow",
        function: handlefollowUser,
      );
    }
  }

  // Unfollow User
  handleUnfollowUser(){
    setState(() {
      isFollowing = false;
    });
    // remove follower
    followersRef
        .doc(widget.profileId)
        .collection('userFollowers')
        .doc(currentUserId)
        .get().then((doc){
          if(doc.exists){
            doc.reference.delete();
          }
        });

    // remove following
    followingRef
        .doc(currentUserId)
        .collection('userFollowing')
        .doc(widget.profileId)
        .get().then((doc){
          if(doc.exists){
            doc.reference.delete();
          }
        });

    // delete activity feed item
    activityFeedRef
        .doc(widget.profileId)
        .collection('feedItems')
        .doc(currentUserId)
        .get().then((doc){
          if(doc.exists){
            doc.reference.delete();
          }
       });
  }

  // follow User
  handlefollowUser(){
  setState(() {
    isFollowing = true;
  });
  //Make auth user follower of That User (update their followers collection)
  followersRef
    .doc(widget.profileId)
    .collection('userFollowers')
    .doc(currentUserId)
    .set({});

  //Put THAT user on your following collection (update following collection)
    followingRef
      .doc(currentUserId)
      .collection('userFollowing')
      .doc(widget.profileId)
      .set({});

    //Add activity feed item for that user to notify about new followers
    activityFeedRef
      .doc(widget.profileId)
      .collection('feedItems')
      .doc(currentUserId)
      .set({
        "type": "follow",
        "ownerId": widget.profileId,
        "username": currentUser.username,
        "userId": currentUserId,
        "userProfileImg": currentUser.photoUrl,
        "timestamp": timestamps,
      });
  }

  buildProfileHeader(){
    return FutureBuilder(
      future: usersRef.doc(widget.profileId).get(),
      builder: (context, snapshot){
        if(!snapshot.hasData){
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 40.0,
                    backgroundColor: Colors.grey,
                    backgroundImage: CachedNetworkImageProvider(
                      user.photoUrl
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                                buildCountColumn('posts', postCount),
                                buildCountColumn('followers', followerCount),
                                buildCountColumn('following', followingCount),
                            ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            buildProfilButton(),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 12.0),
                child: Text(
                  user.username,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.0,
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 4.0),
                child: Text(
                  user.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top:2.0),
                child: Text(
                  user.bio,
                ),
              )
            ],
          ),
        );
      },
    );
  }

  buildProfilePosts(){
    if(isLoading){
      return circularProgress();
    }else if(posts.isEmpty){
     return  Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset('assets/images/no_content.svg', height: 260.0,),
            Padding(padding: EdgeInsets.only(top: 20.0),

                  child: Text('No Posts', style:TextStyle(
                    color: Colors.redAccent,
                    fontSize: 40.0,
                    fontWeight: FontWeight.bold,
                  ) ,
                  ),
              ),
          ],
        ),
      );
    }

    else if(postOrientation == 'grid'){
      List<GridTile> gridTiles = [];
      posts.forEach((post) {
        gridTiles.add(GridTile(child: PostTile(post)));
      });
      return GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        shrinkWrap: true,
        physics:NeverScrollableScrollPhysics(),
        children: gridTiles,
      );
    }else if(postOrientation == 'list'){
      return Column(
      children: posts,
      );
    }
  }

  setPostOrientation(String postOrientation){
    setState(() {
      this.postOrientation = postOrientation;
    });
  }

  buildTogglePostOrientation(){
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          onPressed: () => setPostOrientation('grid'),
          icon: Icon(Icons.grid_on),
          color: postOrientation == 'grid' ? Theme.of(context).primaryColor : Colors.grey,
        ),
        IconButton(
          onPressed: () => setPostOrientation('list'),
          icon: Icon(Icons.list),
          color: postOrientation == 'list' ? Theme.of(context).primaryColor : Colors.grey,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context, titleText: 'Profile'),
      body: ListView(
        children: [
          buildProfileHeader(),
          Divider(),
          buildTogglePostOrientation(),
          Divider(height: 0.0,),
          buildProfilePosts(),
        ],
      ),
    );
  }
}
