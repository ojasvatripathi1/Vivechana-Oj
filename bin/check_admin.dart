import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  print("Checking admin status for vivechanaoaj@gmail.com...");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final users = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: 'vivechanaoaj@gmail.com').get();
  
  if (users.docs.isEmpty) {
    print("User not found!");
  } else {
    for (final doc in users.docs) {
      print("User ID: \${doc.id}");
      print("User Data: \${doc.data()}");
    }
  }
}
