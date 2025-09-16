import 'package:firebase_course/screens/home.dart';
import 'package:firebase_course/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set the database URL explicitly for better compatibility
  FirebaseDatabase.instance.databaseURL =
      'https://blogapp-448d9-default-rtdb.asia-southeast1.firebasedatabase.app';

  // Test Firebase connection
  try {
    DatabaseReference testRef = FirebaseDatabase.instance.ref('test');
    await testRef.set({'test': 'connection'});
    print('Firebase Database connection test successful');
    await testRef.remove(); // Clean up test data

    //Firebase Auth connection Test
    FirebaseAuth auth = FirebaseAuth.instance;
    print('Firebase Auth initialized successfully');
    print('Current user: ${auth.currentUser?.email ?? 'No user logged in'}');

    // Firestore connection test
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final CollectionReference<Map<String, dynamic>> healthchecks =
        firestore.collection('healthchecks');
    final DocumentReference<Map<String, dynamic>> checkRef =
        healthchecks.doc('startup');
    await checkRef.set({
      'ok': true,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    final DocumentSnapshot<Map<String, dynamic>> checkSnap = await checkRef.get();
    print('Firestore connection test: ${checkSnap.data()}');
  } catch (e) {
    print('Firebase connection test failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Blog App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show Loading progress on Login
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If Detected login already not logout
        if (snapshot.hasData && snapshot.data != null) {
          print('User is authenticated: ${snapshot.data!.email}');
          return const HomePage();
        }

        // Otherwise not signed in
        print('User is not authenticated, showing login screen');
        return const LoginScreen();
      },
    );
  }
}
