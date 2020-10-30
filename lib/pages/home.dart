import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluttershare/models/user.dart';
import 'package:fluttershare/pages/activity_feed.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:fluttershare/pages/timeline.dart';
import 'package:fluttershare/pages/upload.dart';
import 'package:fluttershare/pages/search.dart';
import 'package:fluttershare/pages/create_account.dart';
import 'package:fluttershare/pages/profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();
final StorageReference storageRef =  FirebaseStorage.instance.ref();
final usersRef = FirebaseFirestore.instance.collection("users");
final postsRef = FirebaseFirestore.instance.collection("posts");
final commentsRef = FirebaseFirestore.instance.collection("comments");
final activityFeedRef = FirebaseFirestore.instance.collection("feed");

FirebaseFirestore firestore = FirebaseFirestore.instance;
final DateTime timestamps = DateTime.now();
User currentUser;

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  bool isAuth = false;
  PageController pageController;
  int pageIndex = 0;

  @override
  void initState(){

    super.initState();
    pageController = PageController();

    // detecte when user sign in
    googleSignIn.onCurrentUserChanged.listen((account) {
      handleSignIn(account);
    }, onError: (err){
      print('Error Signing in: $err');
    });

    // Reauthentificate User when app is opened
    googleSignIn.signInSilently(suppressErrors: false)
    .then((account) {
      handleSignIn(account);
    }).catchError((err){
           print('Error Signing in: $err');
      });
  }


  handleSignIn(GoogleSignInAccount account){
    if(account != null){

      createUserInFiretore();
      print('User signed in!: $account');
      setState(() {
        isAuth = true;
      });
    }else {
      setState(() {
        isAuth = false;
      });
    }
  }

  createUserInFiretore() async{

    // check if user exists in users collections in database according to their id
    final GoogleSignInAccount user = googleSignIn.currentUser;
    DocumentSnapshot doc = await usersRef.doc(user.id).get();

    if(!doc.exists) {
      // get username from create account, use it to make new user document in users collection
    final username = await Navigator.push(
    context, MaterialPageRoute(builder: (context) =>
    CreateAccount()));

    // if the user does not exist, then we want to make them to the create account page
    usersRef.doc(user.id).setData({
    "id": user.id,
    "username": username,
    "photoUrl": user.photoUrl,
    "email" :user.email,
    "displayName" : user.displayName,
    "bio" : "",
    "timestamps" : timestamps
    });
    doc = await usersRef.doc(user.id).get();
    }

    currentUser = User.fromDocument(doc);
    print(currentUser);
    print(currentUser.username);

  }

  @override
  void  dispose(){
    pageController.dispose();
    super.dispose();
  }

  login(){
    googleSignIn.signIn();
  }

  logout(){
    googleSignIn.signOut();
  }

  onPageChanged(int pageIndex){
      setState(() {
        this.pageIndex = pageIndex;
      });
  }

  //Changing Pages
  onTap(pageIndex){
      pageController.animateToPage(
          pageIndex,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeInOut,
      );
  }

  //Screen after Authentification
  Scaffold buildAuthScreen(){
      return Scaffold(
        body: PageView(
          children: [
            //Timeline(),
             RaisedButton(
              child: Text('Logout'),
              onPressed: logout,
            ),
            ActivityFeed(),
            Upload(currentUser: currentUser),
            Search(),
            Profile(profileId: currentUser?.id),
          ],
          controller: pageController,
          onPageChanged: onPageChanged,
          physics: NeverScrollableScrollPhysics(),
          
        ),
        bottomNavigationBar: CupertinoTabBar(
          currentIndex: pageIndex,
          onTap: onTap,
          activeColor: Theme.of(context).primaryColor,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.whatshot),),
            BottomNavigationBarItem(icon: Icon(Icons.notifications_active),),
            BottomNavigationBarItem(icon: Icon(Icons.photo_camera,size: 35.0,),),
            BottomNavigationBarItem(icon: Icon(Icons.search),),
            BottomNavigationBarItem(icon: Icon(Icons.account_circle),),
          ],
        ),
      );
  }
  //Screen before Authentification
  Scaffold buildUnAuthScreen(){
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors:[
              Theme.of(context).primaryColor,
              Theme.of(context).accentColor,
            ]
          )
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('FlutterShare',
                style: TextStyle(
                  fontFamily: 'Signatra',
                  fontSize: 90.0,
                  color: Colors.white,
                ),
            ),
              GestureDetector(
                onTap: login,
                child: Container(
                  width: 260,
                  height: 60.0,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/google_signin_button.png'),
                      fit: BoxFit.cover
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return isAuth ? buildAuthScreen() : buildUnAuthScreen();
  }
}
