import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'bill_receipt.dart';
import 'purchase_page.dart';

const List<String> supermarketCategories = [
  'සියලුම භාණ්ඩ',
  'හාල් හා ධාන්‍ය',
  'කුළුබඩු',
  'ටින් හා බෝතල් ආහාර',
  'බිස්කට් හා ස්නැක්ස්',
  'බීම වර්ග',
  'කිරි හා කිරි නිෂ්පාදන',
  'පාන් හා බේකරි',
  'ශීත කළ ආහාර',
  'සබන් හා පිරිසිදු කිරීමේ ද්‍රව්‍ය',
  'පුද්ගලික සත්කාර',
  'ළදරු භාණ්ඩ',
  'ලිපි ද්‍රව්‍ය',
  'එළවළු හා පලතුරු',
  'බිත්තර හා මස්',
  'ගෘහ භාණ්ඩ',
  'වෙනත්',
];


Query<Map<String, dynamic>> _myProductsQuery() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) {
    return FirebaseFirestore.instance.collection('products').where('ownerUid', isEqualTo: '__no_user__');
  }
  return FirebaseFirestore.instance.collection('products').where('ownerUid', isEqualTo: uid);
}

CollectionReference<Map<String, dynamic>> _allProductsRef() {
  return FirebaseFirestore.instance.collection('products');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const SupermarketApp());
  } catch (e) {
    runApp(BootErrorApp(error: e));
  }
}

class BootErrorApp extends StatelessWidget {
  final Object error;
  const BootErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 56),
                    const SizedBox(height: 16),
                    const Text(
                      'App එක ආරම්භ කිරීමට ගැටලුවක් ඇත',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 18),
                    const Text(
                      'මෙම error එක පෙන්වුවහොත් screenshot එකක් එවන්න. '
                      'ඒ අනුව නිවැරදි Firebase/Web ගැටලුව fix කරන්න පුළුවන්.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SupermarketApp extends StatelessWidget {
  const SupermarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'සුපිරි වෙළඳසැල් යෙදුම',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F7F5),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _routeForUser(User user) async {
    final admin = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
    if (admin.exists && admin.data()?['active'] != false) return const AdminPanel();

    final customer = await FirebaseFirestore.instance.collection('customers').doc(user.uid).get();
    if (!customer.exists || customer.data()?['active'] == false) {
      await FirebaseAuth.instance.signOut();
      return const LoginPage();
    }
    return const HomePage();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final user = snapshot.data;
        if (user == null) return const LoginPage();
        return FutureBuilder<Widget>(
          future: _routeForUser(user),
          builder: (context, route) {
            if (route.connectionState != ConnectionState.done || !route.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            return route.data!;
          },
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}
class AdminSetupPage extends StatefulWidget {
  const AdminSetupPage({super.key});
  @override
  State<AdminSetupPage> createState() => _AdminSetupPageState();
}

class _AdminSetupPageState extends State<AdminSetupPage> {
  final _shop = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _createAdmin() async {
    final shop = _shop.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (shop.isEmpty || email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop Name, Email සහ අවම අක්ෂර 6ක Password එකක් ඇතුළත් කරන්න.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final existing = await FirebaseFirestore.instance.collection('admins').limit(1).get();
      if (existing.docs.isNotEmpty) {
        throw Exception('Admin account එක දැනටමත් setup කර ඇත.');
      }

      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await FirebaseFirestore.instance.collection('admins').doc(credential.user!.uid).set({
        'email': email,
        'shopName': shop,
        'active': true,
        'role': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Admin account එක සාර්ථකව සාදා ඇත.')),
      );
      Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      var message = 'Admin account එක සාදන්න බැරි වුණා.';
      if (e.code == 'email-already-in-use') message = 'මෙම Email එක දැනටමත් භාවිතා කර ඇත.';
      if (e.code == 'invalid-email') message = 'Email එක නිවැරදිව ඇතුළත් කරන්න.';
      if (e.code == 'weak-password') message = 'Password එක තවත් ශක්තිමත් කරන්න.';
      if (e.code == 'operation-not-allowed') {
        message = 'Firebase Authentication හි Email/Password Login එක enable කරලා නැහැ.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('$message\nCode: ${e.code}\n${e.message ?? ''}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text('Admin account එක සාදන්න බැරි වුණා.\n$raw'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _shop.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🔐 Admin Setup')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              elevation: 5,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 64, color: Colors.green),
                    const SizedBox(height: 12),
                    const Text('පළමු Admin Account එක', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('මෙය පළමු වරට පමණක් setup කරන්න.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 22),
                    TextField(controller: _shop, decoration: const InputDecoration(labelText: 'Shop Name', prefixIcon: Icon(Icons.store), border: OutlineInputBorder())),
                    const SizedBox(height: 14),
                    TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Admin Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Admin Password',
                        helperText: 'අවම අක්ෂර 6ක්',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _createAdmin,
                        icon: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.admin_panel_settings),
                        label: Text(_loading ? 'Setup වෙමින්...' : 'Admin Account සාදන්න'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email සහ Password දෙකම ඇතුළත් කරන්න.')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      var message = 'Login අසාර්ථකයි.';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'wrong-password') {
        message = 'Email හෝ Password වැරදියි.';
      } else if (e.code == 'user-disabled') {
        message = 'මෙම account එක Admin විසින් අක්‍රීය කර ඇත.';
      } else if (e.code == 'invalid-email') {
        message = 'Email එක නිවැරදිව ඇතුළත් කරන්න.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login error: ' + e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('මුලින් Email එක ඇතුළත් කරන්න.')));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset email එක යැව්වා.')));
    } on FirebaseAuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reset error: ' + (e.message ?? e.code))));
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                        child: Icon(Icons.storefront, size: 46, color: Colors.green.shade700),
                      ),
                      const SizedBox(height: 18),
                      const Text('🏪 සුපිරි වෙළඳසැල', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      const Text('Customer Login', style: TextStyle(color: Colors.grey, fontSize: 15)),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined), border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _password,
                        obscureText: _obscure,
                        onSubmitted: (_) => _signIn(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _loading ? null : _signIn,
                          icon: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.login),
                          label: Text(_loading ? 'Signing in...' : 'Sign In'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        child: const Text('Password අමතකද?'),
                      ),
                      const SizedBox(height: 12),
                      const SizedBox(height: 12),
                      const Text(
                        'Registration නැත. Customer Account ලබාගන්නේ App Admin හරහා පමණි.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});
  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _business = TextEditingController();
  final _owner = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _creating = false;
  bool _obscure = true;

  Future<void> _createCustomer() async {
    final business = _business.text.trim();
    final owner = _owner.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (business.isEmpty || owner.isEmpty || email.isEmpty || password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Business Name, Owner Name, Email සහ අවම අක්ෂර 6ක Password එකක් ඇතුළත් කරන්න.')));
      return;
    }

    setState(() => _creating = true);
    FirebaseApp? customerApp;

    try {
      // Create the customer in a separate Firebase app instance so the
      // currently logged-in Admin session is not replaced by the customer.
      const appName = 'customerCreationApp';
      try {
        await Firebase.app(appName).delete();
      } catch (_) {}

      customerApp = await Firebase.initializeApp(
        name: appName,
        options: DefaultFirebaseOptions.currentPlatform,
      );

      final customerAuth = FirebaseAuth.instanceFor(app: customerApp);
      final credential = await customerAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final customerUid = credential.user!.uid;

      // The primary Firebase app is still authenticated as Admin.
      await FirebaseFirestore.instance.collection('customers').doc(customerUid).set({
        'businessName': business,
        'shopName': business,
        'ownerName': owner,
        'email': email,
        'active': true,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _business.clear();
      _owner.clear();
      _email.clear();
      _password.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Customer account එක සාර්ථකව සාදා ඇත.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      var message = 'Customer account එක සාදන්න බැරි වුණා.';
      if (e.code == 'email-already-in-use') {
        message = 'මෙම Email එක දැනටමත් භාවිතා කර ඇත.';
      } else if (e.code == 'invalid-email') {
        message = 'Customer Email එක නිවැරදිව ඇතුළත් කරන්න.';
      } else if (e.code == 'weak-password') {
        message = 'Temporary Password එක තවත් ශක්තිමත් කරන්න.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Firebase Authentication හි Email/Password Login එක enable කරලා නැහැ.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            content: Text('$message\nCode: ${e.code}\n${e.message ?? ''}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 10),
            content: Text('Customer account එක සාදන්න බැරි වුණා.\n$e'),
          ),
        );
      }
    } finally {
      if (customerApp != null) {
        try {
          await customerApp.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _setActive(String uid, bool active) async {
    try {
      await FirebaseFirestore.instance.collection('customers').doc(uid).update({
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(active ? '✅ Customer account එක සක්‍රීය කළා.' : '⛔ Customer account එක අක්‍රීය කළා.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Account status වෙනස් කරන්න බැරි වුණා.\\n$e')),
        );
      }
    }
  }

  Future<void> _removeCustomer(String uid, String businessName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Customer Account ඉවත් කරන්නද?'),
        content: Text(
          '$businessName account එක Customer List එකෙන් ඉවත් කර access එකත් නවත්වනවා.\\n\\n'
          'මෙය කළ පසු customer ට login වීමට නොහැක. ඉවත් කිරීම ආපසු ගත නොහැක.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('අවලංගු කරන්න'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ඉවත් කරන්න'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // With Firebase Spark/client-only setup we cannot delete another user's
      // Firebase Auth account from the Admin client's Auth SDK. Removing the
      // customer document makes AuthGate deny access, so the account is
      // immediately unusable and disappears from the Admin customer list.
      await FirebaseFirestore.instance.collection('customers').doc(uid).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Customer account එක ඉවත් කළා. Login access එකත් නවත්වලා.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer account එක ඉවත් කරන්න බැරි වුණා.\\n$e')),
        );
      }
    }
  }

  Future<void> _claimLegacyProducts(String uid, String businessName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('පරණ භාණ්ඩ මේ Customerට දෙන්නද?'),
        content: Text(
          'Owner ID නැති පරණ Products සියල්ල "$businessName" Customerට assign කරනවා.\n\n'
          'දැනට තිබෙන පරණ product data එක එක් shop එකකට පමණක් අයිති නම් මෙය එක් වරක් කරන්න.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('අවලංගු කරන්න'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Assign කරන්න'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final snapshot = await _allProductsRef().get();
      final legacy = snapshot.docs.where((doc) {
        return (doc.data()['ownerUid'] ?? '').toString().trim().isEmpty;
      }).toList();

      if (legacy.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('පරණ Owner ID නැති Products නැහැ.')),
          );
        }
        return;
      }

      for (var start = 0; start < legacy.length; start += 400) {
        final batch = FirebaseFirestore.instance.batch();
        final end = math.min(start + 400, legacy.length);
        for (final doc in legacy.sublist(start, end)) {
          batch.update(doc.reference, {
            'ownerUid': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          final data = doc.data();
          final barcode = (data['barcode'] ?? '').toString().trim();
          if (barcode.isNotEmpty) {
            await FirebaseFirestore.instance
                .collection('productMaster')
                .doc(barcode)
                .set({
                  'barcode': barcode,
                  'name': (data['name'] ?? '').toString(),
                  'category': (data['category'] ?? '').toString(),
                  'imageUrl': (data['imageUrl'] ?? '').toString(),
                  'imageData': (data['imageData'] ?? '').toString(),
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
          }
        }
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OK: ${legacy.length} පරණ Product records "$businessName" Customerට assign කළා.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Migration error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _business.dispose(); _owner.dispose(); _email.dispose(); _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔐 Admin Panel', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: () => FirebaseAuth.instance.signOut(), icon: const Icon(Icons.logout))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Customer Accounts', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('ගෙවන customers සඳහා login accounts මෙතැනින් සාදන්න.', style: TextStyle(color: Colors.white70)),
            ]),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                const Align(alignment: Alignment.centerLeft, child: Text('➕ අලුත් Customer Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 14),
                TextField(controller: _business, decoration: const InputDecoration(labelText: 'Business Name', prefixIcon: Icon(Icons.store), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Customer Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _password, obscureText: _obscure, decoration: InputDecoration(labelText: 'Temporary Password', helperText: 'අවම අක්ෂර 6ක්', prefixIcon: const Icon(Icons.lock), border: const OutlineInputBorder(), suffixIcon: IconButton(onPressed: () => setState(() => _obscure = !_obscure), icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off)))),
                const SizedBox(height: 14),
                SizedBox(width: double.infinity, height: 50, child: FilledButton.icon(onPressed: _creating ? null : _createCustomer, icon: _creating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add), label: Text(_creating ? 'Creating...' : 'Customer Account සාදන්න'))),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          const Text('👥 Customer List', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('customers').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text('Customer list error: ' + snapshot.error.toString());
              if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              if (snapshot.data!.docs.isEmpty) return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('තව Customer accounts නැහැ.')));
              return Column(children: snapshot.data!.docs.map((doc) {
                final d = doc.data();
                final active = d['active'] != false;
                return Card(child: ListTile(
                  leading: CircleAvatar(child: Icon(active ? Icons.store : Icons.block)),
                  title: Text((d['businessName'] ?? 'Business').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text((d['ownerName'] ?? '').toString() + '\n' + (d['email'] ?? '').toString()),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: active ? 'Disable' : 'Enable',
                        onPressed: () => _setActive(doc.id, !active),
                        icon: Icon(
                          active ? Icons.toggle_on : Icons.toggle_off,
                          size: 32,
                          color: active ? Colors.green : Colors.grey,
                        ),
                      ),
                      IconButton(
                        tooltip: 'පරණ Products මේ Customerට assign කරන්න',
                        onPressed: () => _claimLegacyProducts(
                          doc.id,
                          (d['businessName'] ?? 'Business').toString(),
                        ),
                        icon: const Icon(Icons.move_to_inbox_outlined, color: Colors.orange),
                      ),
                      IconButton(
                        tooltip: 'Remove Customer',
                        onPressed: () => _removeCustomer(
                          doc.id,
                          (d['businessName'] ?? 'Business').toString(),
                        ),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
                ));
              }).toList());
            },
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _shopName = 'සුපිරි වෙළඳසැල';

  @override
  void initState() {
    super.initState();
    _loadShopName();
  }

  Future<void> _loadShopName() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('customers').doc(uid).get();
      final data = doc.data() ?? {};
      final name = (data['shopName'] ?? data['businessName'] ?? '').toString().trim();
      if (mounted && name.isNotEmpty) setState(() => _shopName = name);
    } catch (_) {}
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/94789576303?text=Hello%20SriHarsha%20Digital');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp විවෘත කරන්න බැරි වුණා.')),
      );
    }
  }

  void _openAddProduct(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AddProductPage()));
  }

  void _openStock(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const StockPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '🏪 $_shopName',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shopName,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'සුභ දවසක්! 👋',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'සුපිරි වෙළඳසැල් කළමනාකරණ පද්ධතිය',
                    style: TextStyle(color: Colors.white, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _MenuCard(icon: Icons.inventory_2, title: 'භාණ්ඩ තොගය', subtitle: 'තොගය', onTap: _openStock)),
                const SizedBox(width: 12),
                Expanded(child: _MenuCard(icon: Icons.add_box, title: 'අලුත් භාණ්ඩ', subtitle: 'භාණ්ඩ එකතු කරන්න', onTap: _openAddProduct)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MenuCard(
                    icon: Icons.receipt_long,
                    title: 'අලුත් බිල්පත',
                    subtitle: 'අලුත් බිල්පත',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBillPage())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MenuCard(
                    icon: Icons.qr_code_scanner,
                    title: 'බාර්කෝඩ් ස්කෑන්',
                    subtitle: 'භාණ්ඩය ස්කෑන් කරන්න',
                    onTap: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MenuCard(
              icon: Icons.shopping_cart_checkout,
              title: 'භාණ්ඩ මිලදී ගැනීම්',
              subtitle: 'Purchase / Stock වැඩි කරන්න',
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchasePage())),
            ),
            const SizedBox(height: 20),
            const Text('📊 අද තත්ත්වය', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('dailySales').doc(DateTime.now().toIso8601String().substring(0, 10)).snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? {};
                final bills = (data['billCount'] as num?)?.toInt() ?? 0;
                final revenue = (data['revenue'] as num?)?.toDouble() ?? 0;
                return Row(
                  children: [
                    Expanded(child: _SummaryCard(icon: Icons.shopping_cart, title: 'අද විකුණුම්', value: bills.toString())),
                    const SizedBox(width: 12),
                    Expanded(child: _SummaryCard(icon: Icons.attach_money, title: 'මුළු ආදායම', value: 'Rs. ' + revenue.toStringAsFixed(2))),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BillHistoryPage())),
                icon: const Icon(Icons.calendar_month),
                label: const Text('📅 බිල්පත් ඉතිහාසය / දින අනුව බලන්න'),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 3))],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified, color: Colors.green, size: 18),
                  SizedBox(width: 8),
                  Text('Powered by SriHarsha Digital', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _openWhatsApp(context),
              child: const Text(
                'Technology Solutions | WhatsApp: +94 78 957 6303',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, size: 42, color: Colors.green.shade700),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 30, color: Colors.green.shade700),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}