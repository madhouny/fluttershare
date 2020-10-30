import 'package:flutter/material.dart';
import 'package:fluttershare/widgets/custom_image.dart';
import 'package:fluttershare/widgets/post.dart';
import 'package:fluttershare/pages/post_screen.dart';

class PostTile extends StatelessWidget {
  final Post post;

  PostTile(this.post);

  // Showing Post When user Click oN pOST
  showPost(context){
    Navigator.push(context, MaterialPageRoute(builder:(context)=>
        PostScreen(postId: post.postId, userId: post.ownerId,)
    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showPost(context),
      child: cachedNetworkImage(post.mediaUrl),
    );
  }
}
