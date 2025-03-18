
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../main.dart';
import '../transitions/SlideTransition.dart';

class RequestPage extends StatefulWidget{
  const RequestPage({super.key});

  @override
  State<RequestPage> createState() => _RequestPageState();
}

class _RequestPageState extends State<RequestPage> {

  String? _currentUsername;
  List <Map<String,dynamic>> _requests = [];

  @override
  void initState(){
    super.initState();
    _getCurrentUserName();
  }

  Future<void> _getCurrentUserName() async{
    User? user = FirebaseAuth.instance.currentUser;
    if(user !=null){
      try {
        QuerySnapshot querySnapshot = await FirebaseFirestore.instance
            .collection('Devices')
            .where('username', isEqualTo: user.displayName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          DocumentSnapshot userDoc = querySnapshot.docs.first;
          setState(() {
            _currentUsername = userDoc['username'];
          });
          _getRequests();
        }
      } catch (e) {
        print('Error getting userDoc: $e');
      }
    }

  }

  Future<void> _getRequests() async {
    if(_currentUsername !=null){
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Requests')
          .where('recipientName',isEqualTo: _currentUsername)
          .get();

      setState(() {
        _requests = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['requestId'] = doc.id;
          return data;
        }).toList();
      });
    }
  }

  void _acceptRequest(String requestId , String senderName , String recipientName) async{
    try {
      await FirebaseFirestore.instance.collection('Requests')
          .doc(requestId)
          .update({
        'status': 'accepted',
      });

      var deviceSnapshot = await FirebaseFirestore.instance
          .collection('Devices')
          .where('username' , isEqualTo: recipientName)
          .get();

      if (deviceSnapshot.docs.isNotEmpty) {
        String recipientDocId = deviceSnapshot.docs.first.id;

        await FirebaseFirestore.instance.collection('Devices')
            .doc(recipientDocId)
            .update({
          'Friends': FieldValue.arrayUnion([senderName])
        });

        var senderDoc = await FirebaseFirestore.instance
            .collection('Devices')
            .where('username', isEqualTo: senderName)
            .get();

        if (senderDoc.docs.isNotEmpty) {
          String senderDeviceId = senderDoc.docs.first.id;

          await FirebaseFirestore.instance.collection('Devices').doc(senderDeviceId).update({
            'Friends': FieldValue.arrayUnion([recipientName]),
          });
        }


        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request accepted!')),
        );
      } else {
        throw 'Recipient not found in Devices collection';
      }
      _getRequests();
    }
    catch(e){
      print('Error accepting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to accept request.'),
      ));
    }

  }
  void _declineRequest(String requestId){
    FirebaseFirestore.instance.collection('Requests').doc(requestId).update({
      'status' : 'declined',
    }).then((_){

      setState(() {
        _requests.removeWhere((request) => request['requestId'] == requestId);
      });

      ScaffoldMessenger.of(context).showSnackBar(const
      SnackBar
        (content: Text('Request declined!'),
      ));
      _getRequests();
    });

  }

  void _deleteRequest(String requestId , String senderName)  async {
    try {
      await FirebaseFirestore.instance.collection('Requests')
          .doc(requestId)
          .delete();

      await FirebaseFirestore.instance.collection('Devices')
          .where('username', isEqualTo: _currentUsername)
          .get()
          .then((querySnapshot) async {
        if(querySnapshot.docs.isNotEmpty){
          String recipientDeviceId = querySnapshot.docs.first.id;

          await FirebaseFirestore.instance.collection('Devices').doc(recipientDeviceId).update({
            'Friends': FieldValue.arrayRemove([senderName]),
          });
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend Deleted!')),
      );
      _getRequests();
    }
    catch(e){
      print('Error deleting request: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to delete request.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                context.go('/map', extra: SlideDirection.backward);
              },
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 20),
            const Text('Requests', style: TextStyle(color: Colors.white),),
          ],
        ),
      ),
      body: _requests.isEmpty
          ? const Center(child: Text('No Requests Found'))
          : ListView.builder(
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final request = _requests[index];
          final senderName = request['SenderName'];
          final senderAvatarUrl = request['sender_image'];
          final requestStatus = request['status'];
          return Column(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundImage: senderAvatarUrl != null && senderAvatarUrl.isNotEmpty
                      ? NetworkImage(senderAvatarUrl)
                      : const AssetImage('assets/default_avatar.png'),
                ),
                title: Text( requestStatus == 'accepted'
                    ? '$senderName is now a Friend !! '
                    : 'Request is Sent By $senderName',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if(requestStatus == 'pending')...[
                      TextButton(
                        onPressed: () {
                          _declineRequest(request['requestId']);
                          _deleteRequest(request['requestId'],request['SenderName']);
                        },
                        child: const Text('Decline'),
                      ),
                      TextButton(
                        onPressed: () {
                          _acceptRequest(request['requestId'], request['SenderName'] , _currentUsername!);
                        },
                        child: const Text('Accept'),
                      ),
                    ] else if(requestStatus == 'accepted') ... [
                      TextButton(
                        onPressed: () {
                          _deleteRequest(request['requestId'],request['SenderName']);
                        },
                        child: const Text('Delete'),
                      )
                    ],
                  ],
                ),
              ),
              const Divider(), // Add a line after each request
            ],
          );
        },
      ),
    );
  }
}
