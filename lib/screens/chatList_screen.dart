import 'dart:core';
import 'package:flash_chat/progress.dart';
import 'package:flash_chat/screens/chat_screen.dart';
import 'package:flutter/material.dart';
import 'contacts_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flash_chat/provider/auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:flash_chat/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:contacts_service/contacts_service.dart';

String loggedInUserID;
User loggedInUser;
final DateTime timestamp = DateTime.now();
final activeUsersRef = Firestore.instance.collection('activeUsers');
bool gotAsyncInfo = false;
bool gotContactsInfo = false;
bool isUserNameActuallyNumber;
 Iterable<Contact> contacts;
 List<Contact> contactsList;
 String phoneNumberAtIndex;
 String userName;




bool isNumeric(String str) {
    if(str == null) {
      return false;
    }
    return double.tryParse(str) != null;
  }

class ChatListScreen extends StatefulWidget {
  static const id = 'chatScreen';

  @override
  _ChatListScreenState createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {




  handleContactsButton(BuildContext context) async {
    PermissionStatus permissionStatus = await PermissionHandler().checkPermissionStatus(PermissionGroup.contacts);

    if(permissionStatus.toString() == 'PermissionStatus.granted'){
      Navigator.pushNamed(context, ContactsScreen.id);
    }
    else{
      await PermissionHandler().requestPermissions([PermissionGroup.contacts]); //ask for permission
      Navigator.pushNamed(context, ContactsScreen.id);
    }

  }

void setLoggedInUserID() async{
// final prefs = await SharedPreferences.getInstance();
//     loggedInUserID = prefs.getString("uid");

 await Future.delayed(Duration.zero, (){
   loggedInUserID = Provider.of<Auth>(context, listen: false).uidSharedPref;
 });
 
 setState(() {
   gotAsyncInfo = true;
 });
}

getContacts() async{
PermissionStatus permissionStatus = await PermissionHandler().checkPermissionStatus(PermissionGroup.contacts);

    if(permissionStatus.toString() != 'PermissionStatus.granted'){
       await PermissionHandler().requestPermissions([PermissionGroup.contacts]); //ask for permission   
    }
  
   contacts = await ContactsService.getContacts(withThumbnails: false);
   contactsList = contacts.toList(); 
   setState(() {
   gotContactsInfo = true;
 });
}


@override
  void initState() {
    super.initState();
    getContacts();
   setLoggedInUserID();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text('FlashChat'),
      actions: <Widget>[
        Padding(
          padding: EdgeInsets.only(right: MediaQuery.of(context).size.width*0.038),
          child: GestureDetector(
            child: Icon(Icons.search,color: Colors.white,),
            onTap: (){
              print(contactedUserNames);
              // print(userInfoForSearch[contactedUserNames[0]][1]);
              showSearch(context: context, delegate: SearchUsers());
            },
            ),
        ),
      ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => handleContactsButton(context),
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.message),
      ),
     body: (gotAsyncInfo == true && gotContactsInfo == true) ? Column(
       children: <Widget>[
         ChatList(),
       ],
     ) : Container(),
    );
  }
}

openChatScreen(String name, String phoneNumber, String userID, BuildContext context, String downloadUrl){
Navigator.push(context, MaterialPageRoute(builder: (context)=>ChatScreen(receiverName: name, receiverPhoneNumber: phoneNumber, receiverUserID: userID, imageDownloadUrl: downloadUrl,)));
}

openChatScreenFromSearch(String name, String phoneNumber, String userID, BuildContext context, String downloadUrl){
Navigator.pushReplacement(context, MaterialPageRoute(builder: (context)=>ChatScreen(receiverName: name, receiverPhoneNumber: phoneNumber, receiverUserID: userID, imageDownloadUrl: downloadUrl,)));
}


class MessagedContactsWidget extends StatelessWidget {
  final String contactName;
  final String phoneNumber;
  final String userID;
  final String downloadUrl;
  final String mostRecentMessage;

  MessagedContactsWidget({this.contactName = 'defaultName', this.phoneNumber, this.userID, this.downloadUrl, this.mostRecentMessage});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
          onTap: ()=> openChatScreen(contactName, phoneNumber, userID, context, this.downloadUrl),
          child: Column(
        children: <Widget>[
          ListTile(
            leading: (this.downloadUrl == 'NoImage') ? CircleAvatar(child: Image.asset('images/blah.png')) :  CircleAvatar( backgroundColor: Colors.transparent ,radius: 23, child: ClipOval(
  child: FadeInImage.assetNetwork(
              fadeInDuration: Duration(milliseconds: 200),
              fadeOutDuration: Duration(milliseconds: 200),
              placeholder: 'gifs/ld9.gif',
              image: this.downloadUrl,
              fit: BoxFit.fill,
            ),
),
),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[  
                (contactName == 'defaultName') ? Text(phoneNumber, style: TextStyle(fontSize: 20), textAlign: TextAlign.start,) : Text(contactName, style: TextStyle(fontSize: 20),),
                SizedBox(
                  height: 3,
                ),
                Text(mostRecentMessage, 
                     style: TextStyle(fontSize: 15, color: Colors.black54,),
                     textAlign: TextAlign.start,
                     ),
              ],
            ),
          ),  
          Container(
            width: MediaQuery.of(context).size.width*0.9,
            child: Divider(
              height: 13,
              thickness: 0.4,
              indent: MediaQuery.of(context).size.width*0.14,
            ),
          ),
        ],
      ),
    );
  }
}

final contactedUserNames = [];
Map<String,List<String>> userInfoForSearch = {};
int counter=0;
class ChatList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: activeUsersRef.document(loggedInUserID).collection('messagedUsers').orderBy('timestamp', descending:false).snapshots(),
      builder: (context, snapshot){

        if(!snapshot.hasData){
          return Container();
        }
        
        
        final messagedUsers = snapshot.data.documents;
        List<MessagedContactsWidget> listOfMessagedContactsWidget = [];
          for(var users in messagedUsers){
          final String userPhoneNumber = users.data['phoneNumber'];
          final String downloadUrl = users.data['image'];
          final String receiverID = users.data['receiverID'];
          final String mostRecentText = users.data['mostRecentMessage'];
          for(int index = 0; index < contactsList.length; index++){
            phoneNumberAtIndex = (contactsList[index].phones.isEmpty) ? ' ' : contactsList[index].phones.firstWhere((anElement) => anElement.value != null).value;
            String trimmedPhoneNumber = phoneNumberAtIndex.split(" ").join("");
            if(userPhoneNumber == trimmedPhoneNumber){
              userName = contactsList[index].displayName;
               if(contactedUserNames.length!=0){
                 counter = 0;
                for(int i=0;i<contactedUserNames.length;i++){
                 if(contactedUserNames[i]==userName){
                   counter++;
                  break;
                 }               
                }
                if(counter==0){
                 contactedUserNames.add(userName);
                 userInfoForSearch[userName] = [trimmedPhoneNumber.toString(), downloadUrl, receiverID, mostRecentText];
                }
             }
             else{
              contactedUserNames.add(userName);
              userInfoForSearch[userName] = [trimmedPhoneNumber.toString(), downloadUrl, receiverID, mostRecentText];
             }
              break;
            }
            else{
              userName = userPhoneNumber;
            }
          }
          
        isUserNameActuallyNumber = isNumeric(userName);
           var messagedContact;
         if(isUserNameActuallyNumber == true){
            messagedContact = MessagedContactsWidget(phoneNumber: userPhoneNumber, userID: receiverID, downloadUrl: downloadUrl,mostRecentMessage: mostRecentText,);
         }
         else{
            messagedContact = MessagedContactsWidget(contactName: userName, phoneNumber: userPhoneNumber, userID: receiverID, downloadUrl: downloadUrl, mostRecentMessage: mostRecentText,);
         }

          
     
      listOfMessagedContactsWidget.add(messagedContact);
      }
      
      return Expanded(
              child: SingleChildScrollView(
                child: Column(
          children: listOfMessagedContactsWidget,
        ),
              ),
      );
        
      },      

    );
  }
}


class SearchUsers extends SearchDelegate<String>{
  @override
 List<Widget> buildActions(BuildContext context){
   return [IconButton(
     icon: Icon(Icons.clear),
     onPressed: (){query = "";},
     )];
 }

 @override
 Widget buildLeading(BuildContext context){
   return IconButton(
     icon: AnimatedIcon(icon: AnimatedIcons.menu_arrow, progress: transitionAnimation,),
     onPressed: (){
       close(context, null);
     },
   );
 }

 @override 
 Widget buildResults(BuildContext context){
   return null;
 }

 @override 
 Widget buildSuggestions(BuildContext context){
    if(query.isEmpty){
   return Container(
     alignment: Alignment.topCenter,
     padding: EdgeInsets.symmetric(vertical: 50, horizontal: 60),
     child: Text('Start typing a name to continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),),
     );
    }
  else{
    
   final suggestionsList = contactedUserNames.where((p) => (p.toLowerCase()).startsWith(query.toLowerCase())).toList();

   return ListView.builder(
     itemCount: suggestionsList.length,
     itemBuilder: (context,index) => ListTile(
       onTap: ()=> openChatScreenFromSearch(suggestionsList[index], userInfoForSearch[suggestionsList[index]][0], userInfoForSearch[suggestionsList[index]][2], context, userInfoForSearch[suggestionsList[index]][1])  ,
       leading: (userInfoForSearch[suggestionsList[index]][1] == 'NoImage') ? CircleAvatar(child: Image.asset('images/blah.png')) :  CircleAvatar( backgroundColor: Colors.transparent ,radius: 23, child: ClipOval(
  child: FadeInImage.assetNetwork(
              fadeInDuration: Duration(milliseconds: 200),
              fadeOutDuration: Duration(milliseconds: 200),
              placeholder: 'gifs/ld9.gif',
              image: userInfoForSearch[suggestionsList[index]][1],
              fit: BoxFit.fill,
            ),
),
),
       title: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: <Widget>[
           RichText(
             text: TextSpan(
               text: suggestionsList[index].substring(0,query.length),
               style: TextStyle(
                 color: Colors.black, fontWeight: FontWeight.bold,
                 fontSize: 20,
                 ),
                 children: [
                   TextSpan(
                    text: suggestionsList[index].substring(query.length),
                    style: TextStyle(color: Colors.black54, fontSize: 20),
                   ),
                 ]),  
           ),
           SizedBox(
             height: 3,
           ),
           Text(userInfoForSearch[suggestionsList[index]][3], 
                     style: TextStyle(fontSize: 15, color: Colors.black54,),
                     textAlign: TextAlign.start,
                     ),
         ],
       ),
     ),
   );
   
  }
 }
}






// GestureDetector(
//           onTap: ()=> openChatScreen(contactName, phoneNumber, userID, context, this.downloadUrl),
//           child: Column(
//         children: <Widget>[
//           ListTile(
//             leading: (this.downloadUrl == 'NoImage') ? CircleAvatar(child: Image.asset('images/blah.png')) :  CircleAvatar( backgroundColor: Colors.transparent ,radius: 23, child: ClipOval(
//   child: FadeInImage.assetNetwork(
//               fadeInDuration: Duration(milliseconds: 200),
//               fadeOutDuration: Duration(milliseconds: 200),
//               placeholder: 'gifs/ld9.gif',
//               image: this.downloadUrl,
//               fit: BoxFit.fill,
//             ),
// ),
// ),
//             title: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: <Widget>[  
//                 (contactName == 'defaultName') ? Text(phoneNumber, style: TextStyle(fontSize: 20), textAlign: TextAlign.start,) : Text(contactName, style: TextStyle(fontSize: 20),),
//                 SizedBox(
//                   height: 3,
//                 ),
//                 Text(mostRecentMessage, 
//                      style: TextStyle(fontSize: 15, color: Colors.black54,),
//                      textAlign: TextAlign.start,
//                      ),
//               ],
//             ),
//           ),  
//           Container(
//             width: MediaQuery.of(context).size.width*0.9,
//             child: Divider(
//               height: 13,
//               thickness: 0.4,
//               indent: MediaQuery.of(context).size.width*0.14,
//             ),
//           ),
//         ],
//       ),
//     );