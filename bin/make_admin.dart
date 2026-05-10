// script
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  print("Starting admin assignment script...");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final users = await FirebaseFirestore.instance.collection('users').where('email', isEqualTo: 'vivechanaoaj@gmail.com').get();
  
  if (users.docs.isEmpty) {
    print("Could not find user with email vivechanaoaj@gmail.com");
    return;
  }
  
  for (final doc in users.docs) {
    await doc.reference.update({'isAdmin': true});
    print('Updated user \${doc.id} to be Admin');
  }
}
