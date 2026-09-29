import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

Query<Map<String, dynamic>> _myBillsQuery() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) {
    return FirebaseFirestore.instance.collection('bills').where('ownerUid', isEqualTo: '__no_user__');
  }
  return FirebaseFirestore.instance.collection('bills').where('ownerUid', isEqualTo: uid);
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
  int _adminTab = 0;
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

  Future<void> _resetCustomerPassword(String email, String shopName) async {
    final address = email.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('මෙම Customerගේ Email එක නැහැ.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('🔑 Customer Password Reset'),
        content: Text(
          '$shopName සඳහා Password Reset Email එකක් යවන්නද?\n\n'
          'Email එකේ link එක open කරලා Customerට අලුත් Password එකක් දාන්න පුළුවන්.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('අවලංගු කරන්න'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset Email යවන්න'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: address);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ $address වෙත Password Reset Email එක යැව්වා.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password Reset error: ${e.message ?? e.code}')),
        );
      }
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(child: FilledButton.icon(
                  onPressed: () => setState(() => _adminTab = 0),
                  icon: const Icon(Icons.people),
                  label: const Text('Customers'),
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => setState(() => _adminTab = 1),
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('🔔 දැනුම්දීම්'),
                )),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _adminTab,
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF1B5E20), Color(0xFF43A047)]),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Customer Accounts', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
                          SizedBox(height: 6),
                          Text('ගෙවන customers සඳහා login accounts මෙතැනින් සාදන්න.', style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Align(alignment: Alignment.centerLeft, child: Text('➕ අලුත් Customer Account', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                            const SizedBox(height: 14),
                            TextField(controller: _business, decoration: const InputDecoration(labelText: 'Shop Name', prefixIcon: Icon(Icons.store), border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _owner, decoration: const InputDecoration(labelText: 'Owner Name', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Customer Email', prefixIcon: Icon(Icons.email), border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: _obscure,
                              decoration: InputDecoration(
                                labelText: 'Temporary Password',
                                helperText: 'අවම අක්ෂර 6ක්',
                                prefixIcon: const Icon(Icons.lock),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: FilledButton.icon(
                                onPressed: _creating ? null : _createCustomer,
                                icon: _creating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.person_add),
                                label: Text(_creating ? 'Creating...' : 'Customer Account සාදන්න'),
                              ),
                            ),
                          ],
                        ),
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
                        return Column(
                          children: snapshot.data!.docs.map((doc) {
                            final d = doc.data();
                            final active = d['active'] != false;
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(child: Icon(active ? Icons.store : Icons.block)),
                                title: Text((d['businessName'] ?? 'Business').toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text((d['ownerName'] ?? '').toString() + '\n' + (d['email'] ?? '').toString()),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(tooltip: active ? 'Disable' : 'Enable', onPressed: () => _setActive(doc.id, !active), icon: Icon(active ? Icons.toggle_on : Icons.toggle_off, size: 32, color: active ? Colors.green : Colors.grey)),
                                    IconButton(tooltip: 'පරණ Products මේ Customerට assign කරන්න', onPressed: () => _claimLegacyProducts(doc.id, (d['businessName'] ?? 'Business').toString()), icon: const Icon(Icons.move_to_inbox_outlined, color: Colors.orange)),
                                    IconButton(tooltip: 'Customer Password Reset', onPressed: () => _resetCustomerPassword((d['email'] ?? '').toString(), (d['businessName'] ?? 'Customer').toString()), icon: const Icon(Icons.lock_reset, color: Colors.blue)),
                                    IconButton(tooltip: 'Remove Customer', onPressed: () => _removeCustomer(doc.id, (d['businessName'] ?? 'Business').toString()), icon: const Icon(Icons.delete_outline, color: Colors.red)),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
                const PaymentNotificationPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class PaymentNotificationPage extends StatefulWidget {
  const PaymentNotificationPage({super.key});
  @override State<PaymentNotificationPage> createState() => _PaymentNotificationPageState();
}

class _PaymentNotificationPageState extends State<PaymentNotificationPage> {
  String? _customerUid;
  String _customerName = '';
  final _message = TextEditingController();
  final _paymentDate = TextEditingController();
  bool _sending = false;
  String? _editingId;

  @override
  void dispose() {
    _message.dispose();
    _paymentDate.dispose();
    super.dispose();
  }

  String _dateKey(String displayDate) {
    final parts = displayDate.split('/');
    if (parts.length != 3) return '';
    return '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _paymentDate.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      setState(() {});
    }
  }

  void _startEdit(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    setState(() {
      _editingId = doc.id;
      _customerUid = (d['customerUid'] ?? '').toString();
      _customerName = (d['customerName'] ?? 'Customer').toString();
      _message.text = (d['message'] ?? '').toString();
      _paymentDate.text = (d['paymentDate'] ?? '').toString();
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingId = null;
      _customerUid = null;
      _customerName = '';
      _message.clear();
      _paymentDate.clear();
    });
  }

  Future<void> _delete(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('දැනුම්දීම මකන්නද?'),
        content: Text('${doc.data()?['customerName'] ?? 'Customer'} වෙත ඇති මෙම reminder එක මකා දමන්නද?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('නැහැ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('මකන්න'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await doc.reference.delete();
      if (_editingId == doc.id) _cancelEdit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🗑️ Reminder එක මකා දැම්මා.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder එක මකන්න බැරි වුණා.\n$e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_customerUid == null || _customerUid!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('මුලින් Customer කෙනෙක් තෝරන්න.')),
      );
      return;
    }
    if (_message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('පණිවිඩය ඇතුළත් කරන්න.')),
      );
      return;
    }
    if (_paymentDate.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment Date එක තෝරන්න.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      final data = {
        'customerUid': _customerUid,
        'customerName': _customerName,
        'title': '💳 ගෙවීම් මතක් කිරීම',
        'message': _message.text.trim(),
        'paymentDate': _paymentDate.text.trim(),
        'paymentDateKey': _dateKey(_paymentDate.text.trim()),
        'read': false,
      };

      if (_editingId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('notifications').add(data);
      } else {
        data['updatedAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('notifications').doc(_editingId).update(data);
      }

      final edited = _editingId != null;
      _cancelEdit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(edited ? '✅ Reminder එක update කළා.' : '✅ $_customerName වෙත reminder එක යැව්වා.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder එක save කරන්න බැරි වුණා.\n$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('customers').orderBy('createdAt', descending: true).snapshots(),
      builder: (context, customerSnapshot) {
        if (customerSnapshot.hasError) {
          return Center(child: Text('Customer list error: ${customerSnapshot.error}'));
        }
        if (!customerSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final customers = customerSnapshot.data!.docs;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('notifications').orderBy('createdAt', descending: true).snapshots(),
          builder: (context, reminderSnapshot) {
            if (reminderSnapshot.hasError) {
              return Center(child: Text('Reminder list error: ${reminderSnapshot.error}'));
            }
            if (!reminderSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final reminders = reminderSnapshot.data!.docs;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          _editingId == null ? '🔔 Customer Payment Reminder' : '✏️ Reminder එක Edit කරන්න',
                          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _editingId == null
                              ? 'Customer කෙනෙක් තෝරගෙන payment date එක සහ message එක manually යවන්න.'
                              : 'Reminder එකේ Customer, දිනය හෝ පණිවිඩය වෙනස් කරන්න.',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: customers.any((d) => d.id == _customerUid) ? _customerUid : null,
                          decoration: const InputDecoration(
                            labelText: 'Customer තෝරන්න',
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                          items: customers.map((doc) {
                            final d = doc.data();
                            final name = (d['businessName'] ?? d['shopName'] ?? 'Customer').toString();
                            return DropdownMenuItem(value: doc.id, child: Text(name));
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) return;
                            final d = customers.firstWhere((doc) => doc.id == value).data();
                            setState(() {
                              _customerUid = value;
                              _customerName = (d['businessName'] ?? d['shopName'] ?? 'Customer').toString();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _paymentDate,
                          readOnly: true,
                          onTap: _pickDate,
                          decoration: const InputDecoration(
                            labelText: 'Payment Date',
                            hintText: 'දිනය තෝරන්න',
                            prefixIcon: Icon(Icons.calendar_month),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _message,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'දැනුම්දීමේ පණිවිඩය',
                            hintText: 'උදා: ඔබගේ ගෙවීම 05/10/2026 දිනට ගෙවීමට නියමිතයි.',
                            prefixIcon: Icon(Icons.message_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _sending ? null : _save,
                            icon: _sending
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(_editingId == null ? Icons.send : Icons.save),
                            label: Text(_sending
                                ? 'සුරැකෙමින්...'
                                : (_editingId == null ? '🔔 දැනුම්දීම යවන්න' : '💾 Reminder Update කරන්න')),
                          ),
                        ),
                        if (_editingId != null) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _sending ? null : _cancelEdit,
                            icon: const Icon(Icons.close),
                            label: const Text('Edit Cancel'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text('📋 යවා ඇති Payment Reminders',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (reminders.isEmpty)
                  const Card(child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('තව Payment Reminders නැහැ.'),
                  )),
                ...reminders.map((doc) {
                  final d = doc.data();
                  final customer = (d['customerName'] ?? 'Customer').toString();
                  final date = (d['paymentDate'] ?? '').toString();
                  final message = (d['message'] ?? '').toString();
                  final sent = d['sentAt'] is Timestamp;
                  return Card(
                    child: ListTile(
                      leading: Icon(sent ? Icons.notifications_active : Icons.notifications_none,
                          color: sent ? Colors.green : Colors.orange),
                      title: Text(customer, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        (date.isEmpty ? 'දිනයක් නැත' : '💳 ගෙවීම් දිනය: $date') +
                        '\n' + message +
                        (sent ? '\n✅ උදේ notification යවා ඇත' : ''),
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 0,
                        children: [
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _startEdit(doc),
                          ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _delete(doc),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }
}

class CustomerNotificationsPage extends StatelessWidget {
  const CustomerNotificationsPage({super.key});
  Future<void> _markRead(DocumentSnapshot<Map<String,dynamic>> doc) async {try{await doc.reference.update({'read':true});}catch(_){}}
  @override Widget build(BuildContext context){
    final uid=FirebaseAuth.instance.currentUser?.uid??'__none__';
    return Scaffold(
      appBar:AppBar(title:const Text('🔔 දැනුම්දීම්')),
      body:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
        stream:FirebaseFirestore.instance.collection('notifications').where('customerUid',isEqualTo:uid).snapshots(),
        builder:(context,snapshot){
          if(snapshot.hasError)return Center(child:Text('දැනුම්දීම් දෝෂයක්: ${snapshot.error}'));
          if(!snapshot.hasData)return const Center(child:CircularProgressIndicator());
          final docs=[...snapshot.data!.docs];
          docs.sort((a,b){
            final at=a.data()['createdAt'],bt=b.data()['createdAt'];
            final am=at is Timestamp?at.millisecondsSinceEpoch:0;
            final bm=bt is Timestamp?bt.millisecondsSinceEpoch:0;
            return bm.compareTo(am);
          });
          if(docs.isEmpty)return const Center(child:Text('දැනට දැනුම්දීම් නැහැ.'));
          return ListView.separated(
            padding:const EdgeInsets.all(14),itemCount:docs.length,
            separatorBuilder:(_,__)=>const SizedBox(height:8),
            itemBuilder:(context,index){
              final doc=docs[index],d=doc.data(),read=d['read']==true;
              final msg=(d['message']??'').toString(),date=(d['paymentDate']??'').toString();
              return Card(child:ListTile(
                onTap:()=>_markRead(doc),
                leading:Icon(read?Icons.notifications_none:Icons.notifications_active,color:read?Colors.grey:Colors.green),
                title:Text((d['title']??'දැනුම්දීම').toString(),style:TextStyle(fontWeight:read?FontWeight.normal:FontWeight.bold)),
                subtitle:Text(msg+(date.isEmpty?'':'\n💳 ගෙවීම් දිනය: $date')),
              ));
            },
          );
        },
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
    _setupPushNotifications();
  }

  Future<void> _setupPushNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await FirebaseFirestore.instance.collection('customers').doc(uid).set(
          {'fcmTokens': FieldValue.arrayUnion([token])},
          SetOptions(merge: true),
        );
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (newToken.isNotEmpty) {
          await FirebaseFirestore.instance.collection('customers').doc(uid).set(
            {'fcmTokens': FieldValue.arrayUnion([newToken])},
            SetOptions(merge: true),
          );
        }
      });
    } catch (_) {}
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddProductPage()),
    );
  }

  void _openStock(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StockPage()),
    );
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
            tooltip: 'දැනුම්දීම්',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CustomerNotificationsPage()),
            ),
            icon: const Icon(Icons.notifications_active_outlined),
          ),
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'සුභ දවසක්! 👋',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'සුපිරි වෙළඳසැල් කළමනාකරණ පද්ධතිය',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _MenuCard(
                    icon: Icons.inventory_2,
                    title: 'භාණ්ඩ තොගය',
                    subtitle: 'තොගය',
                    onTap: () => _openStock(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MenuCard(
                    icon: Icons.add_box,
                    title: 'අලුත් භාණ්ඩ',
                    subtitle: 'භාණ්ඩ එකතු කරන්න',
                    onTap: () => _openAddProduct(context),
                  ),
                ),
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
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NewBillPage()),
                    ),
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
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PurchasePage()),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '📊 අද තත්ත්වය',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _myBillsQuery().snapshots(),
              builder: (context, snapshot) {
                final todayKey = DateTime.now().toIso8601String().substring(0, 10);
                final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                final todayDocs = docs.where((doc) => (doc.data()['dateKey'] ?? '').toString() == todayKey).toList();
                final bills = todayDocs.length;
                final revenue = todayDocs.fold<double>(0, (sum, doc) => sum + ((doc.data()['total'] as num?)?.toDouble() ?? 0));
                return Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.shopping_cart,
                        title: 'අද විකුණුම්',
                        value: bills.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        icon: Icons.attach_money,
                        title: 'මුළු ආදායම',
                        value: 'Rs. ' + revenue.toStringAsFixed(2),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BillHistoryPage()),
                ),
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 35,
                  ),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'අඩු තොග',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'අඩු තොග ඇති භාණ්ඩ මෙහි පෙන්වනු ඇත.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  const Text(
                    'Powered by SriHarsha Digital',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => _openWhatsApp(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: Text(
                        'Technology Solutions | WhatsApp: +94 78 957 6303',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  String _selectedCategory = 'සියලුම භාණ්ඩ';

  bool _isAllowedCategory(String value) {
    return supermarketCategories.skip(1).contains(value);
  }

  DateTime? _parseExpiryDate(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    final slash = RegExp(r'^([0-9]{1,2})/([0-9]{1,2})/([0-9]{4})$').firstMatch(text);
    if (slash != null) return DateTime(int.parse(slash.group(3)!), int.parse(slash.group(2)!), int.parse(slash.group(1)!));
    final iso = RegExp(r'^([0-9]{4})-([0-9]{1,2})-([0-9]{1,2})$').firstMatch(text);
    if (iso != null) return DateTime(int.parse(iso.group(1)!), int.parse(iso.group(2)!), int.parse(iso.group(3)!));
    return DateTime.tryParse(text);
  }

  int? _daysUntilExpiry(String value) {
    final expiry = _parseExpiryDate(value);
    if (expiry == null) return null;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return expiry.difference(today).inDays;
  }

  Future<void> _showStockAlerts(List<DocumentSnapshot<Map<String, dynamic>>> docs) async {
    final lowStock = docs.where((doc) => ((doc.data()?['stockQuantity'] as num?)?.toInt() ?? 0) <= 5).toList();
    final expiring = docs.where((doc) {
      final days = _daysUntilExpiry((doc.data()?['expiryDate'] ?? '').toString());
      return days != null && days <= 5;
    }).toList();
    if (lowStock.isEmpty && expiring.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('දැනට අඩු තොග හෝ ඉක්මනින් කල් ඉකුත් වන භාණ්ඩ නැහැ.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Row(children: [Icon(Icons.notifications_active, color: Colors.red), SizedBox(width: 8), Expanded(child: Text('භාණ්ඩ දැනුම්දීම්'))]),
        content: SizedBox(width: double.maxFinite, child: ListView(shrinkWrap: true, children: [
          if (lowStock.isNotEmpty) ...[
            Text('🔴 අඩු තොග (${lowStock.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ...lowStock.map((doc) { final data=doc.data()??{}; final name=(data['name']??'නම නැත').toString(); final qty=(data['stockQuantity'] as num?)?.toInt()??0; return ListTile(dense:true, leading:const Icon(Icons.inventory_2,color:Colors.red), title:Text(name), subtitle:Text('දැනට තොගය: $qty')); }),
            const Divider(),
          ],
          if (expiring.isNotEmpty) ...[
            Text('🔴 කල් ඉකුත් වීමට දින 5ක් ඇතුළත (${expiring.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ...expiring.map((doc) { final data=doc.data()??{}; final name=(data['name']??'නම නැත').toString(); final expiry=(data['expiryDate']??'').toString(); final days=_daysUntilExpiry(expiry); final label=days!=null&&days<0?'කල් ඉකුත් වී ඇත':days==0?'අද කල් ඉකුත් වේ':'තව දින $days'; return ListTile(dense:true, leading:const Icon(Icons.event_busy,color:Colors.red), title:Text(name), subtitle:Text('$expiry • $label')); }),
          ],
        ])),
        actions: [FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('හරි'))],
      ),
    );
  }
  Future<void> _editProduct(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final nameController = TextEditingController(text: (data['name'] ?? '').toString());
    final barcodeController = TextEditingController(text: (data['barcode'] ?? '').toString());
    final buyController = TextEditingController(text: (data['buyPrice'] ?? '').toString());
    final sellController = TextEditingController(text: (data['sellingPrice'] ?? '').toString());
    final stockController = TextEditingController(text: (data['stockQuantity'] ?? 0).toString());
    final limitController = TextEditingController(text: (data['lowStockLimit'] ?? 5).toString());
    final expiryController = TextEditingController(text: (data['expiryDate'] ?? '').toString());
    String category = _isAllowedCategory((data['category'] ?? '').toString())
        ? (data['category'] ?? '').toString()
        : 'වෙනත්';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('භාණ්ඩය සංස්කරණය කරන්න'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'භාණ්ඩ නම'),
                ),
                TextField(
                  controller: barcodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'බාර්කෝඩ්'),
                ),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'භාණ්ඩ වර්ගය'),
                  items: supermarketCategories.skip(1).map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  ).toList(),
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                TextField(
                  controller: buyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'මිලදී ගැනීමේ මිල (රු.)'),
                ),
                TextField(
                  controller: sellController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'විකුණුම් මිල (රු.)'),
                ),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'තොග ප්‍රමාණය'),
                ),
                TextField(
                  controller: limitController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'අඩු තොග සීමාව'),
                ),
                TextField(
                  controller: expiryController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'කල් ඉකුත් වන දිනය',
                    hintText: 'DD/MM/YYYY',
                    suffixIcon: Icon(Icons.calendar_month),
                  ),
                  onTap: () async {
                    final current = _parseExpiryDate(expiryController.text);
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: current ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      expiryController.text = picked.day.toString().padLeft(2, '0') + '/' +
                          picked.month.toString().padLeft(2, '0') + '/' +
                          picked.year.toString();
                      setDialogState(() {});
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('අවලංගු කරන්න'),
            ),
            FilledButton(
              onPressed: () async {
                final buy = double.tryParse(buyController.text.trim());
                final sell = double.tryParse(sellController.text.trim());
                final stock = int.tryParse(stockController.text.trim());
                final limit = int.tryParse(limitController.text.trim());
                if (nameController.text.trim().isEmpty ||
                    barcodeController.text.trim().isEmpty ||
                    buy == null ||
                    sell == null ||
                    stock == null ||
                    limit == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('කරුණාකර සියලු විස්තර නිවැරදිව ඇතුළත් කරන්න.')),
                  );
                  return;
                }
                try {
                  await doc.reference.update({
                    'name': nameController.text.trim(),
                    'barcode': barcodeController.text.trim(),
                    'category': category,
                    'buyPrice': buy,
                    'sellingPrice': sell,
                    'stockQuantity': stock,
                    'lowStockLimit': limit,
                    'expiryDate': expiryController.text.trim(),
                  });
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('භාණ්ඩය සංස්කරණය කිරීමේදී දෝෂයක් ඇතිවුණා.')),
                    );
                  }
                }
              },
              child: const Text('සුරකින්න'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    barcodeController.dispose();
    buyController.dispose();
    sellController.dispose();
    stockController.dispose();
    limitController.dispose();
    expiryController.dispose();

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('භාණ්ඩ විස්තර යාවත්කාලීන කළා.')),
      );
    }
  }

  Future<void> _deleteProduct(DocumentSnapshot<Map<String, dynamic>> doc, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('භාණ්ඩය මකන්නද?'),
        content: Text('“$name” භාණ්ඩය තොගයෙන් ස්ථිරවම මකා දමන්නද?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('අවලංගු කරන්න'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('මකන්න'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await doc.reference.delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('භාණ්ඩය මකා දැමුවා.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('භාණ්ඩය මකා දැමීමේදී දෝෂයක් ඇතිවුණා.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'භාණ්ඩ තොගය',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _myProductsQuery().snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('භාණ්ඩ තොග දත්ත ලබාගැනීමේදී දෝෂයක් ඇතිවුණා.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
              )
                ..sort((a, b) => (a.data()['name'] ?? '').toString().toLowerCase()
                    .compareTo((b.data()['name'] ?? '').toString().toLowerCase()));
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'තවම භාණ්ඩ සුරැකලා නැහැ.',
                style: TextStyle(fontSize: 17, color: Colors.grey),
              ),
            );
          }

          final filteredDocs = _selectedCategory == 'සියලුම භාණ්ඩ'
              ? docs
              : docs.where((doc) {
                  final category = (doc.data()['category'] ?? '').toString();
                  return category == _selectedCategory;
                }).toList();

          final lowStockDocs = docs.where((doc) {
            final quantity = (doc.data()['stockQuantity'] as num?)?.toInt() ?? 0;
            return quantity <= 5;
          }).toList();
          final expiringDocs = docs.where((doc) {
            final days = _daysUntilExpiry((doc.data()['expiryDate'] ?? '').toString());
            return days != null && days <= 5;
          }).toList();
          final hasAlerts = lowStockDocs.isNotEmpty || expiringDocs.isNotEmpty;

          return Column(
            children: [
              if (hasAlerts)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Material(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showStockAlerts(docs),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            const Icon(Icons.notifications_active, color: Colors.red, size: 30),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '🔴 දැනුම්දීම්: ' + lowStockDocs.length.toString() + ' අඩු තොග' +
                                (expiringDocs.isNotEmpty ? ' • ' + expiringDocs.length.toString() + ' කල් ඉකුත්වීම්' : ''),
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.red),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(
                height: 58,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: supermarketCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (context, index) {
                    final category = supermarketCategories[index];
                    final selected = category == _selectedCategory;
                    return ChoiceChip(
                      label: Text(category),
                      selected: selected,
                      onSelected: (_) {
                        setState(() => _selectedCategory = category);
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Text(
                          '“$_selectedCategory” යටතේ භාණ්ඩ නැහැ.',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data();
                          final name =
                              (data['name'] ?? 'නම නැත').toString();
                          final barcode =
                              (data['barcode'] ?? '').toString();
                          final category =
                              (data['category'] ?? '').toString();
                          final quantity =
                              (data['stockQuantity'] as num?)?.toInt() ?? 0;
                          final limit =
                              (data['lowStockLimit'] as num?)?.toInt() ?? 5;
                          final sellingPrice =
                              (data['sellingPrice'] as num?)?.toDouble() ?? 0;
                          final expiryDate = (data['expiryDate'] ?? '').toString();
                          final expiryDays = _daysUntilExpiry(expiryDate);
                          final isExpiryAlert = expiryDays != null && expiryDays <= 5;
                          final isOut = quantity <= 0;
                          final isLow = quantity > 0 && quantity <= limit;
                          final statusColor = isOut || isExpiryAlert
                              ? Colors.red
                              : (isLow ? Colors.orange : Colors.green);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Builder(
                                        builder: (context) {
                                          final imageData =
                                              (data['imageData'] ?? '').toString();
                                          final imageUrl =
                                              (data['imageUrl'] ?? '').toString();

                                          if (imageData.isNotEmpty) {
                                            try {
                                              return ClipRRect(
                                                borderRadius: BorderRadius.circular(12),
                                                child: Image.memory(
                                                  base64Decode(imageData),
                                                  width: 58,
                                                  height: 58,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      CircleAvatar(
                                                    radius: 29,
                                                    backgroundColor:
                                                        statusColor.withValues(alpha: 0.12),
                                                    child: Icon(
                                                      isOut
                                                          ? Icons.remove_shopping_cart
                                                          : Icons.inventory_2,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            } catch (_) {}
                                          }

                                          if (imageUrl.isNotEmpty) {
                                            return ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.network(
                                                imageUrl,
                                                width: 58,
                                                height: 58,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    CircleAvatar(
                                                  radius: 29,
                                                  backgroundColor:
                                                      statusColor.withValues(alpha: 0.12),
                                                  child: Icon(
                                                    isOut
                                                        ? Icons.remove_shopping_cart
                                                        : Icons.inventory_2,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }

                                          return CircleAvatar(
                                            radius: 29,
                                            backgroundColor:
                                                statusColor.withValues(alpha: 0.12),
                                            child: Icon(
                                              isOut
                                                  ? Icons.remove_shopping_cart
                                                  : Icons.inventory_2,
                                              color: statusColor,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text([
                                              if (category.isNotEmpty)
                                                'වර්ගය: $category',
                                              if (barcode.isNotEmpty)
                                                'බාර්කෝඩ්: $barcode',
                                              'විකුණුම් මිල: රු. ${sellingPrice.toStringAsFixed(2)}',
                                              if (expiryDate.isNotEmpty)
                                                'කල් ඉකුත් වීම: ' + expiryDate +
                                                    (isExpiryAlert
                                                        ? ' • ' + (expiryDays! < 0 ? 'කල් ඉකුත් වී ඇත' : expiryDays == 0 ? 'අද' : 'දින ' + expiryDays.toString() + 'කින්')
                                                        : ''),
                                            ].join('\\n')),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$quantity',
                                            style: TextStyle(
                                              fontSize: 21,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                          Text(
                                            isOut
                                                ? 'තොග අවසන්'
                                                : (isLow
                                                    ? 'අඩු තොග'
                                                    : 'තොග තිබේ'),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: statusColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            minimumSize:
                                                const Size.fromHeight(48),
                                          ),
                                          onPressed: () {
                                            _editProduct(filteredDocs[index]);
                                          },
                                          icon: const Icon(Icons.edit),
                                          label: const Text('සංස්කරණය'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            minimumSize:
                                                const Size.fromHeight(48),
                                          ),
                                          onPressed: () {
                                            _deleteProduct(
                                              filteredDocs[index],
                                              name,
                                            );
                                          },
                                          icon: const Icon(Icons.delete),
                                          label: const Text('මකන්න'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  String _imageUrl = '';
  String _imageData = '';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController(text: '5');
  final _expiryDateController = TextEditingController();
  bool _saving = false;
  final ImagePicker _imagePicker = ImagePicker();
  bool _uploadingImage = false;

  Future<void> _captureProductImage() async {
    if (_uploadingImage) return;
    try {
      if (mounted) setState(() => _uploadingImage = true);
      final file = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 45,
        maxWidth: 500,
        maxHeight: 500,
      );
      if (file == null) {
        if (mounted) setState(() => _uploadingImage = false);
        return;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('Photo file එක හිස්.');
      if (bytes.length > 700 * 1024) {
        throw Exception('Photo එක තව පොඩි කරලා නැවත Capture කරන්න.');
      }
      final encoded = base64Encode(bytes);
      if (!mounted) return;
      setState(() {
        _imageData = encoded;
        _imageUrl = '';
        _uploadingImage = false;
      });
      _showMessage('✅ Photo එක සාර්ථකව එකතු කළා.');
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        _showMessage(
          'Photo එක එකතු කිරීමට නොහැකි වුණා: ' +
              e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    }
  }

  bool _isAllowedCategory(String value) {
    return supermarketCategories.skip(1).contains(value);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _buyPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final scannedCode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );

    if (!mounted || scannedCode == null || scannedCode.isEmpty) return;

    await _fillProductFromBarcode(scannedCode);
  }

  Map<String, String> _parseGs1Barcode(String barcode) {
    final result = <String, String>{};
    // GS1 AI 17 = expiry date (YYMMDD).
    final expiryMatch = RegExp(r'(?:^|\\x1D)17(\\d{6})').firstMatch(barcode);
    if (expiryMatch != null) {
      final v = expiryMatch.group(1)!;
      final year = 2000 + int.parse(v.substring(0, 2));
      final month = int.parse(v.substring(2, 4));
      final day = int.parse(v.substring(4, 6));
      try {
        final date = DateTime(year, month, day);
        result['expiryDate'] =
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (_) {}
    }
    // GS1 price AIs 392x/393x may contain a variable price.
    final priceMatch = RegExp(r'(?:^|\\x1D)39[23]([0-9])([0-9]+)').firstMatch(barcode);
    if (priceMatch != null) {
      final raw = priceMatch.group(2)!;
      final decimals = int.tryParse(priceMatch.group(1)!) ?? 0;
      if (raw.isNotEmpty) {
        final number = int.tryParse(raw);
        if (number != null) {
          result['sellingPrice'] = (number / (decimals == 0 ? 1 : math.pow(10, decimals))).toStringAsFixed(decimals);
        }
      }
    }
    return result;
  }

  Future<void> _fillProductFromBarcode(String barcode) async {
    final scannedBarcode = barcode.trim();
    if (scannedBarcode.isEmpty) return;

    final gs1 = _parseGs1Barcode(scannedBarcode);

    setState(() {
      _barcodeController.text = scannedBarcode;

      // If the barcode itself contains expiry/price (GS1), use those first.
      if (gs1['expiryDate'] != null) {
        _expiryDateController.text = gs1['expiryDate']!;
      }
      if (gs1['sellingPrice'] != null) {
        _sellingPriceController.text = gs1['sellingPrice']!;
      }
    });

    // First use our own products database. This is the important part:
    // once a barcode has been saved before, its buying price, selling price
    // and expiry date will automatically appear on the next scan.
    try {
      final result = await _myProductsQuery()
          .where('barcode', isEqualTo: scannedBarcode)
          .limit(1)
          .get();

      if (!mounted) return;

      if (result.docs.isNotEmpty) {
        final data = result.docs.first.data();

        setState(() {
          _imageUrl = (data['imageUrl'] ?? '').toString();
          _imageData = (data['imageData'] ?? '').toString();
          _nameController.text = (data['name'] ?? '').toString();

          final savedCategory = (data['category'] ?? '').toString();
          _categoryController.text =
              _isAllowedCategory(savedCategory) ? savedCategory : 'වෙනත්';

          // Our saved buying price belongs to this supermarket, so always
          // restore it when this barcode is scanned again.
          final buyPrice = data['buyPrice'];
          if (buyPrice != null) {
            _buyPriceController.text = buyPrice.toString();
          }

          // A GS1 price is more specific than our saved value. Otherwise
          // restore the supermarket's saved selling price.
          if (gs1['sellingPrice'] == null) {
            final sellingPrice = data['sellingPrice'];
            if (sellingPrice != null) {
              _sellingPriceController.text = sellingPrice.toString();
            }
          }

          // Same rule for expiry: GS1 value wins, otherwise restore saved
          // expiry date.
          if (gs1['expiryDate'] == null) {
            final expiryDate = data['expiryDate'];
            if (expiryDate != null) {
              _expiryDateController.text = expiryDate.toString();
            }
          }
        });

        _showMessage(
          'බාර්කෝඩ් එකෙන් භාණ්ඩ නම, වර්ගය, මිලදී ගැනීමේ මිල, විකුණුම් මිල සහ කල් ඉකුත් වන දිනය ස්වයංක්‍රීයව පුරවා ගත්තා.',
        );
        return;
      }
    } catch (e) {
      // Continue to the public barcode database if our lookup is unavailable.
    }

    // This barcode is not in this customer's own products.
    // Check the shared Product Master and copy ONLY common information.
    // Another shop's buy price, selling price, stock and expiry are private.
    try {
      final masterDoc = await FirebaseFirestore.instance
          .collection('productMaster')
          .doc(scannedBarcode)
          .get();

      if (!mounted) return;

      if (masterDoc.exists) {
        final data = masterDoc.data() ?? <String, dynamic>{};

        setState(() {
          _nameController.text = (data['name'] ?? '').toString();

          final savedCategory = (data['category'] ?? '').toString();
          _categoryController.text =
              _isAllowedCategory(savedCategory) ? savedCategory : 'වෙනත්';

          _imageUrl = (data['imageUrl'] ?? '').toString();
          _imageData = (data['imageData'] ?? '').toString();

          // These values belong to THIS shop and must be entered separately.
          _buyPriceController.clear();
          _sellingPriceController.clear();
          _stockController.clear();
          _expiryDateController.clear();
          _lowStockController.text = '5';
        });

        _showMessage(
          '🌐 Shared Product Master එකෙන් නම, වර්ගය සහ Photo එක පමණක් auto-fill කළා. '
          'ඔයාගේ shop එකේ මිල, තොගය සහ expiry date වෙනම දාන්න.',
        );
        return;
      }
    } catch (_) {
      // Continue to the public barcode database if the master is unavailable.
    }

    // If this is a new barcode, get the general product information online.
    // Shop-specific buying/selling prices cannot be reliably obtained online,
    // so those will be entered once and then remembered in Firestore.
    try {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v3/product/$scannedBarcode',
        <String, String>{
          'product_type': 'all',
          'fields': 'product_name,categories,brands,image_url,image_front_url,image_small_url',
        },
      );

      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'SupermarketApp/1.0 (barcode product lookup)',
        },
      ).timeout(const Duration(seconds: 8));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final product = decoded['product'];

        if (product is Map<String, dynamic>) {
          final name = (product['product_name'] ?? '').toString().trim();
          final categories =
              (product['categories'] ?? '').toString().trim();
          final imageUrl = (product['image_front_url'] ??
                  product['image_url'] ??
                  product['image_small_url'] ??
                  '')
              .toString()
              .trim();

          if (name.isNotEmpty || categories.isNotEmpty || imageUrl.isNotEmpty) {
            setState(() {
              if (imageUrl.isNotEmpty) {
                _imageUrl = imageUrl;
              }
              if (name.isNotEmpty) {
                _nameController.text = name;
              }

              if (categories.isNotEmpty) {
                final onlineCategory = categories.split(',').first.trim();
                _categoryController.text =
                    _isAllowedCategory(onlineCategory)
                        ? onlineCategory
                        : 'වෙනත්';
              } else {
                _categoryController.text = 'වෙනත්';
              }
            });

            _showMessage(
              'භාණ්ඩ නම සහ වර්ගය auto-fill කළා. මිලදී/විකුණුම් මිල මේ shop එකට අදාළ නිසා පළමු වරට ඇතුළත් කරන්න. ඊළඟ scan එකේ ඒ මිල දෙක auto-fill වේ.',
            );
            return;
          }
        }
      }

      _showMessage(
        'මේ බාර්කෝඩ් එක හමු වුණේ නැහැ. පළමු වරට විස්තර ඇතුළත් කර සුරකින්න. ඊළඟ වර scan කළාම මිලත් auto-fill වේ.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'බාර්කෝඩ් දත්ත ගබඩාවට සම්බන්ධ වීමට බැරි වුණා. පළමු වරට විස්තර අතින් ඇතුළත් කරන්න. ඊළඟ scan එකේ අපේ database එකෙන් මිල auto-fill වේ.',
        isError: true,
      );
    }
  }
  Future<void> _saveProduct() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final buyPrice = double.tryParse(_buyPriceController.text.trim());
    final sellingPrice = double.tryParse(_sellingPriceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());
    final lowStock = int.tryParse(_lowStockController.text.trim());

    if (buyPrice == null ||
        sellingPrice == null ||
        stock == null ||
        lowStock == null) {
      _showMessage('කරුණාකර අංක නිවැරදිව ඇතුළත් කරන්න.', isError: true);
      return;
    }

    if (mounted) setState(() => _saving = true);

    try {
      // Keep the user informed while the Firestore write is in progress.
      _showMessage('⏳ භාණ්ඩය database එකට සුරකිමින්...');

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null || currentUid.isEmpty) {
        throw Exception('Customer login session එක හමු වුණේ නැහැ.');
      }

      final data = <String, dynamic>{
        'ownerUid': currentUid,
        'name': _nameController.text.trim(),
        'imageUrl': _imageUrl.trim(),
        'imageData': _imageData,
        'barcode': _barcodeController.text.trim(),
        'category': _categoryController.text.trim(),
        'buyPrice': buyPrice,
        'sellingPrice': sellingPrice,
        'stockQuantity': stock,
        'lowStockLimit': lowStock,
        'expiryDate': _expiryDateController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Do not leave the button spinning forever if Firestore is blocked,
      // offline, or the security rules reject the write.
      await _allProductsRef()
          .add(data)
          .timeout(
            const Duration(seconds: 25),
            onTimeout: () => throw TimeoutException(
              'Database save එක තත්පර 25ක් ඇතුළත අවසන් වුණේ නැහැ.',
            ),
          );

      final savedBarcode = _barcodeController.text.trim();
      if (savedBarcode.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('productMaster')
            .doc(savedBarcode)
            .set({
              'barcode': savedBarcode,
              'name': _nameController.text.trim(),
              'category': _categoryController.text.trim(),
              'imageUrl': _imageUrl.trim(),
              'imageData': _imageData,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      if (!mounted) return;
      _formKey.currentState!.reset();
      _nameController.clear();
      _barcodeController.clear();
      _imageUrl = '';
      _imageData = '';
      _categoryController.clear();
      _buyPriceController.clear();
      _sellingPriceController.clear();
      _stockController.clear();
      _lowStockController.text = '5';
      _expiryDateController.clear();

      _showMessage('✅ භාණ්ඩය සාර්ථකව සුරැකුවා.');
    } on FirebaseException catch (e) {
      if (!mounted) return;
      _showMessage(
        '❌ Firebase save error: ${e.code}\n${e.message ?? ''}',
        isError: true,
      );
    } on TimeoutException catch (e) {
      if (!mounted) return;
      _showMessage(
        '❌ ${e.message ?? 'Database save timeout වුණා.'}\nInternet සහ Firestore පරීක්ෂා කරන්න.',
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(
        '❌ භාණ්ඩය සුරැකීමට නොහැකි වුණා.\n$e',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onScan,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: onScan == null
              ? null
              : IconButton(
                  tooltip: 'කැමරාවෙන් බාර්කෝඩ් ස්කෑන් කරන්න',
                  icon: const Icon(Icons.camera_alt, color: Colors.green),
                  onPressed: onScan,
                ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'මෙය අවශ්‍යයි';
    return null;
  }

  String? _number(String? value) {
    if (value == null || value.trim().isEmpty) return 'මෙය අවශ්‍යයි';
    if (double.tryParse(value.trim()) == null) return 'අංකයක් ඇතුළත් කරන්න';
    return null;
  }

  String? _integer(String? value) {
    if (value == null || value.trim().isEmpty) return 'මෙය අවශ්‍යයි';
    if (int.tryParse(value.trim()) == null) {
      return 'සම්පූර්ණ අංකයක් ඇතුළත් කරන්න';
    }
    return null;
  }

  Widget _photoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '📷 භාණ්ඩයේ Photo එක',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'භාණ්ඩය හඳුනාගැනීමට photo එකක් capture කරලා save කරන්න.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Column(
            children: [
              if (_imageData.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(_imageData),
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 260,
                      child: Center(child: Icon(Icons.broken_image, size: 50)),
                    ),
                  ),
                )
              else if (_imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _imageUrl,
                    height: 260,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 260,
                      child: Center(child: Icon(Icons.broken_image, size: 50)),
                    ),
                  ),
                )
              else
                Container(
                  height: 260,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Icon(Icons.photo_camera_outlined, size: 80, color: Colors.green),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: _saving || _uploadingImage ? null : _captureProductImage,
                  icon: _uploadingImage
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.camera_alt),
                  label: Text(
                    _uploadingImage
                        ? 'Photo එක upload වෙමින්...'
                        : (_imageUrl.isEmpty ? '📷 Photo එක Capture කරන්න' : '📷 Photo එක නැවත Capture කරන්න'),
                  ),
                ),
              ),
              if (_imageData.isNotEmpty || _imageUrl.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Photo එක සාර්ථකව එකතු කරලා තියෙනවා ✓',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'අලුත් භාණ්ඩ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.edit_note), text: 'භාණ්ඩ විස්තර'),
              Tab(icon: Icon(Icons.camera_alt), text: '📷 Photo'),
            ],
          ),
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [

            const Text(
              'භාණ්ඩ විස්තර',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'භාණ්ඩය තොගයට සුරකින්න.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 18),
            _field(
              controller: _nameController,
              label: 'භාණ්ඩ නම',
              icon: Icons.shopping_bag_outlined,
              validator: _required,
            ),
            _field(
              controller: _barcodeController,
              label: 'බාර්කෝඩ්',
              icon: Icons.qr_code,
              keyboardType: TextInputType.number,
              validator: _required,
              onScan: _scanBarcode,
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: _isAllowedCategory(_categoryController.text)
                    ? _categoryController.text
                    : null,
                decoration: InputDecoration(
                  labelText: 'භාණ්ඩ වර්ගය',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: supermarketCategories
                    .skip(1)
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                validator: (value) =>
                    value == null || value.isEmpty ? 'භාණ්ඩ වර්ගයක් තෝරන්න' : null,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _categoryController.text = value);
                  }
                },
              ),
            ),
            _field(
              controller: _buyPriceController,
              label: 'මිලදී ගැනීමේ මිල (රු.)',
              icon: Icons.shopping_cart_checkout,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _number,
            ),
            _field(
              controller: _sellingPriceController,
              label: 'විකුණුම් මිල (රු.)',
              icon: Icons.sell_outlined,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: _number,
            ),
            _field(
              controller: _stockController,
              label: 'තොග ප්‍රමාණය',
              icon: Icons.inventory_2_outlined,
              keyboardType: TextInputType.number,
              validator: _integer,
            ),
            _field(
              controller: _expiryDateController,
              label: 'කල් ඉකුත් වන දිනය',
              icon: Icons.event_outlined,
              keyboardType: TextInputType.datetime,
            ),
            _field(
              controller: _lowStockController,
              label: 'අඩු තොග සීමාව',
              icon: Icons.warning_amber_outlined,
              keyboardType: TextInputType.number,
              validator: _integer,
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveProduct,
                icon: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'සුරකිමින්...' : 'භාණ්ඩය සුරකින්න'),
              ),
            ),
            const SizedBox(height: 20),

                      ],
                    ),
                    _photoTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



Future<String> _getCurrentShopName() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || uid.isEmpty) return 'සුපිරි වෙළඳසැල';
  try {
    final doc = await FirebaseFirestore.instance.collection('customers').doc(uid).get();
    final data = doc.data() ?? {};
    final name = (data['shopName'] ?? data['businessName'] ?? '').toString().trim();
    return name.isEmpty ? 'සුපිරි වෙළඳසැල' : name;
  } catch (_) {
    return 'සුපිරි වෙළඳසැල';
  }
}

class BillHistoryPage extends StatefulWidget {
  const BillHistoryPage({super.key});
  @override
  State<BillHistoryPage> createState() => _BillHistoryPageState();
}

class _BillHistoryPageState extends State<BillHistoryPage> {
  DateTime _selectedDate = DateTime.now();

  String _dateKey(DateTime date) => date.toIso8601String().substring(0, 10);

  String _displayDate(DateTime date) =>
      date.day.toString().padLeft(2, '0') + '/' +
      date.month.toString().padLeft(2, '0') + '/' +
      date.year.toString();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'බිල්පත් දිනය තෝරන්න',
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _deleteBill(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final billNumber = (data['billNumber'] ?? doc.id).toString();
    final dateKey = (data['dateKey'] ?? _dateKey(_selectedDate)).toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('බිල්පත මකන්නද?'),
        content: Text(
          'බිල්පත් අංකය: ${billNumber}\n'
          'මුදල: Rs. ${total.toStringAsFixed(2)}\n\n'
          'මෙය මැකීමෙන් එම බිල්පතේ භාණ්ඩ stock එකට නැවත එකතු කර, '
          'එම දවසේ ආදායමෙන් මුදල අඩු කරනු ඇත.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('අවලංගු කරන්න'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('මකන්න'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final firestore = FirebaseFirestore.instance;
      await firestore.runTransaction((transaction) async {
        final items = (data['items'] as List?) ?? const [];
        final productSnapshots =
            <String, DocumentSnapshot<Map<String, dynamic>>>{};

        for (final raw in items) {
          final item = Map<String, dynamic>.from(raw as Map);
          final productId = (item['productId'] ?? '').toString();
          if (productId.isEmpty) continue;
          final ref = firestore.collection('products').doc(productId);
          productSnapshots[productId] = await transaction.get(ref);
        }

        for (final raw in items) {
          final item = Map<String, dynamic>.from(raw as Map);
          final productId = (item['productId'] ?? '').toString();
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          if (productId.isEmpty || quantity <= 0) continue;
          final snap = productSnapshots[productId];
          if (snap == null || !snap.exists) continue;
          final currentStock =
              (snap.data()?['stockQuantity'] as num?)?.toInt() ?? 0;
          transaction.update(snap.reference, {
            'stockQuantity': currentStock + quantity,
          });
        }

        final ownerUid = (data['ownerUid'] ?? FirebaseAuth.instance.currentUser?.uid ?? '').toString();
        if (ownerUid.isEmpty) throw Exception('මෙම බිල්පතේ customer account තොරතුරු නැහැ.');
        final salesRef = firestore.collection('dailySales').doc(ownerUid + '_' + dateKey);
        transaction.set(
          salesRef,
          {
            'dateKey': dateKey,
            'billCount': FieldValue.increment(-1),
            'revenue': FieldValue.increment(-total),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.delete(doc.reference);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('බිල්පත මකා දැමුවා. Stock සහ ආදායමත් යාවත්කාලීන කළා.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'බිල්පත මකා දැමීමට නොහැකි වුණා: ' +
                e.toString().replaceFirst('Exception: ', ''),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _dateKey(_selectedDate);
    final todayKey = _dateKey(DateTime.now());
    final canDelete = key == todayKey;

    return Scaffold(
      appBar: AppBar(title: const Text('බිල්පත් ඉතිහාසය')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month, size: 34),
                title: const Text('දිනය තෝරන්න',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(_displayDate(_selectedDate)),
                trailing: const Icon(Icons.arrow_drop_down),
                onTap: _pickDate,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _myBillsQuery().snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text('බිල්පත් ලබාගැනීමේදී දෝෂයක් ඇතිවුණා.'),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Double-check ownership on the client as well as the Firestore
                // query. A customer must never see another customer's bill.
                final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  final ownerUid = (data['ownerUid'] ?? '').toString();
                  final dateKey = (data['dateKey'] ?? '').toString();
                  return currentUid.isNotEmpty &&
                      ownerUid == currentUid &&
                      dateKey == key;
                }).toList();
                docs.sort((a, b) {
                  final at = a.data()['createdAt'] as Timestamp?;
                  final bt = b.data()['createdAt'] as Timestamp?;
                  return (bt?.millisecondsSinceEpoch ?? 0)
                      .compareTo(at?.millisecondsSinceEpoch ?? 0);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _displayDate(_selectedDate) + ' සඳහා බිල්පත් නැහැ.',
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final total = (data['total'] as num?)?.toDouble() ?? 0;
                    final items = (data['items'] as List?) ?? const [];
                    final billNumber =
                        (data['billNumber'] ?? doc.id).toString();

                    final receiptItems = items.map<Map<String, dynamic>>((raw) {
                      final item = Map<String, dynamic>.from(raw as Map);
                      return {
                        'name': (item['name'] ?? '').toString(),
                        'barcode': (item['barcode'] ?? '').toString(),
                        'price': (item['price'] as num?)?.toDouble() ?? 0,
                        'quantity': (item['quantity'] as num?)?.toInt() ?? 0,
                        'total': (item['total'] as num?)?.toDouble() ?? 0,
                      };
                    }).toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
                        title: Text(
                          'බිල්පත ' + (billNumber.length > 8 ? billNumber.substring(0, 8) : billNumber),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          items.length.toString() + ' භාණ්ඩ  •  Rs. ' + total.toStringAsFixed(2),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'සම්පූර්ණ බිල්පත',
                              icon: const Icon(Icons.receipt_long, color: Colors.green),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BillReceiptPage(
                                    billNumber: billNumber,
                                    shopName: (data['shopName'] ?? 'සුපිරි වෙළඳසැල').toString(),
                                    dateKey: (data['dateKey'] ?? key).toString(),
                                    items: receiptItems,
                                    total: total,
                                  ),
                                ),
                              ),
                            ),
                            if (canDelete)
                              IconButton(
                                tooltip: 'මකන්න',
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteBill(doc),
                              )
                            else
                              const Icon(Icons.expand_more),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BillReceiptPage(
                                      billNumber: billNumber,
                                      shopName: (data['shopName'] ?? 'සුපිරි වෙළඳසැල').toString(),
                                      dateKey: (data['dateKey'] ?? key).toString(),
                                      items: receiptItems,
                                      total: total,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('🧾 සම්පූර්ණ බිල්පත බලන්න / Print / Image Share'),
                              ),
                            ),
                          ),
                          for (final raw in items)
                            ListTile(
                              dense: true,
                              title: Text((raw['name'] ?? '').toString()),
                              subtitle: Text(
                                raw['quantity'].toString() + ' x Rs. ' +
                                ((raw['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                              ),
                              trailing: Text(
                                'Rs. ' + ((raw['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NewBillPage extends StatefulWidget {
  const NewBillPage({super.key});

  @override
  State<NewBillPage> createState() => _NewBillPageState();
}

class _NewBillPageState extends State<NewBillPage> {
  final List<_BillItem> _items = [];
  final TextEditingController _searchController = TextEditingController();
  bool _saving = false;
  String _searchQuery = '';
  String _manualCategory = 'සියලුම භාණ්ඩ';
  String _quickSearch = '';

  double get _total => _items.fold(0, (sum, item) => sum + item.total);
  int get _itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  String get _todayKey => DateTime.now().toIso8601String().substring(0, 10);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _scanAndAdd() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;

    final snapshot = await _myProductsQuery()
        .where('barcode', isEqualTo: code.trim())
        .limit(1)
        .get();

    if (!mounted) return;
    if (snapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('මෙම බාර්කෝඩ් එකට භාණ්ඩයක් හමු වුණේ නැහැ. මුලින් භාණ්ඩය තොගයට එකතු කරන්න.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await _addProduct(snapshot.docs.first);
  }

  Future<void> _addProduct(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final name = (data['name'] ?? 'නම නොමැත').toString();
    final barcode = (data['barcode'] ?? '').toString();
    final price = (data['sellingPrice'] as num?)?.toDouble() ?? 0;
    final stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
    final imageUrl = (data['imageUrl'] ?? '').toString();
    final imageData = (data['imageData'] ?? '').toString();

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name සඳහා විකිණුම් මිලක් නැහැ.')),
      );
      return;
    }

    final existingIndex = _items.indexWhere((item) => item.docId == doc.id);
    final currentQty = existingIndex >= 0 ? _items[existingIndex].quantity : 0;

    if (stock <= 0 || currentQty + 1 > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name සඳහා තිබෙන තොගය $stock යි.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      if (existingIndex >= 0) {
        _items[existingIndex].quantity++;
      } else {
        _items.add(_BillItem(
          docId: doc.id,
          name: name,
          barcode: barcode,
          price: price,
          quantity: 1,
          stock: stock,
          imageUrl: imageUrl,
          imageData: imageData,
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name බිල්පතට එකතු කළා.'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  void _changeQuantity(int index, int change) {
    final item = _items[index];
    final newQty = item.quantity + change;
    if (newQty <= 0) {
      setState(() => _items.removeAt(index));
      return;
    }
    if (newQty > item.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.name + ' සඳහා තිබෙන තොගය ' + item.stock.toString() + ' යි.')),
      );
      return;
    }
    setState(() => item.quantity = newQty);
  }

  void _setQuantity(int index, String value) {
    final qty = int.tryParse(value.trim());
    if (qty == null || qty < 1) return;
    final item = _items[index];
    if (qty > item.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(item.name + ' සඳහා තිබෙන තොගය ' + item.stock.toString() + ' යි.')),
      );
      return;
    }
    setState(() => item.quantity = qty);
  }

  Future<void> _saveBill() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final billRef = firestore.collection('bills').doc();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null || uid.isEmpty) throw Exception('Customer account එක හමු වුණේ නැහැ.');
      final salesRef = firestore.collection('dailySales').doc(uid + '_' + _todayKey);
      final savedTotal = _total;
      final shopName = await _getCurrentShopName();

      await firestore.runTransaction((transaction) async {
        final latest = <String, DocumentSnapshot<Map<String, dynamic>>>{};

        for (final item in _items) {
          final ref = firestore.collection('products').doc(item.docId);
          latest[item.docId] = await transaction.get(ref);
        }

        for (final item in _items) {
          final snap = latest[item.docId]!;
          if (!snap.exists) {
            throw Exception('භාණ්ඩය හමු වුණේ නැහැ: ' + item.name);
          }
          final data = snap.data()!;
          final currentStock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
          if (currentStock < item.quantity) {
            throw Exception(item.name + ' සඳහා ප්‍රමාණවත් තොගයක් නැහැ. දැන් තිබෙන්නේ ' + currentStock.toString() + ' යි.');
          }
          transaction.update(snap.reference, {
            'stockQuantity': currentStock - item.quantity,
          });
        }

        final billItems = _items.map((item) => {
          'productId': item.docId,
          'name': item.name,
          'barcode': item.barcode,
          'price': item.price,
          'quantity': item.quantity,
          'total': item.total,
          'imageData': item.imageData,
        }).toList();

        transaction.set(billRef, {
           'billNumber': billRef.id,
          'ownerUid': uid,
          'shopName': shopName,
          'items': billItems,
          'total': savedTotal,
          'createdAt': FieldValue.serverTimestamp(),
          'dateKey': _todayKey,
        });

        transaction.set(
          salesRef,
          {
            'dateKey': _todayKey,
            'billCount': FieldValue.increment(1),
            'revenue': FieldValue.increment(savedTotal),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;

      final receiptItems = _items.map((item) => <String, dynamic>{
        'name': item.name,
        'barcode': item.barcode,
        'price': item.price,
        'quantity': item.quantity,
        'total': item.total,
        'imageData': item.imageData,
      }).toList();

      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => BillReceiptPage(
            billNumber: billRef.id,
            shopName: shopName,
            dateKey: _todayKey,
            items: receiptItems,
            total: savedTotal,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('බිල්පත සුරැකීමට නොහැකි වුණා: ' + e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _productImage(_BillItem item) {
    if (item.imageData.isNotEmpty) {
      try {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(base64Decode(item.imageData), width: 58, height: 58, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    if (item.imageUrl.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.shopping_bag, color: Colors.green.shade700),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        item.imageUrl,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 58,
          height: 58,
          color: Colors.green.shade50,
          child: Icon(Icons.shopping_bag, color: Colors.green.shade700),
        ),
      ),
    );
  }

  Widget _billItemsList() {
    if (_items.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 72, color: Colors.grey),
            SizedBox(height: 12),
            Text('බිල්පත සකස් කිරීමට පටන් ගන්න',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 6),
            Text('බාර්කෝඩ් ස්කෑන් කරන්න හෝ භාණ්ඩය සොයන්න',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _productImage(item),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 3),
                          Text('විකුණුම් මිල  Rs. ' + item.price.toStringAsFixed(2),
                              style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('අයිතම එකතුව  Rs. ' + item.total.toStringAsFixed(2),
                              style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'ඉවත් කරන්න',
                      onPressed: () => setState(() => _items.removeAt(index)),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    const Text('ප්‍රමාණය', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => _changeQuantity(index, -1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    SizedBox(
                      width: 62,
                      height: 42,
                      child: TextFormField(
                        key: ValueKey(item.docId + '_' + item.quantity.toString()),
                        initialValue: item.quantity.toString(),
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onFieldSubmitted: (value) => _setQuantity(index, value),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _changeQuantity(index, 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    const Spacer(),
                    Text('තොගයේ ' + item.stock.toString(),
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barcodeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.green.shade100),
            ),
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner, size: 70, color: Colors.green.shade700),
                const SizedBox(height: 12),
                const Text('බාර්කෝඩ් මගින් එකතු කරන්න',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                const SizedBox(height: 7),
                const Text('භාණ්ඩයේ බාර්කෝඩ් එක ස්කෑන් කළ විට නම, මිල සහ තොගය ස්වයංක්‍රීයව ලැබේ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _scanAndAdd,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('බාර්කෝඩ් ස්කෑන් කරන්න',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_items.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('බිල්පතේ භාණ්ඩ',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 250, child: _billItemsList()),
          ],
        ],
      ),
    );
  }


  Widget _quickSaleTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: TextField(
            onChanged: (value) => setState(() => _quickSearch = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: '⭐ Barcode නැති භාණ්ඩ සොයන්න...',
              prefixIcon: const Icon(Icons.star, color: Colors.orange),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 2, 14, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('⭐ ඉක්මන් විකිණීම — Barcode නැති භාණ්ඩ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _myProductsQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text('භාණ්ඩ ලැයිස්තුව ලබාගැනීමේදී දෝෂයක් ඇතිවුණා.'));
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final name = (data['name'] ?? '').toString().toLowerCase();
                final barcode = (data['barcode'] ?? '').toString().trim();
                final stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
                return barcode.isEmpty && stock > 0 &&
                    (_quickSearch.isEmpty || name.contains(_quickSearch));
              }).toList();
              if (docs.isEmpty) {
                return const Center(
                  child: Text('Barcode නැති භාණ්ඩ හමු වුණේ නැහැ.\nAdd Product එකේ Barcode හිස්ව තබා save කරන්න.',
                      textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                );
              }
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.88),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index], data = doc.data();
                  final name = (data['name'] ?? 'නම නැත').toString();
                  final price = (data['sellingPrice'] as num?)?.toDouble() ?? 0;
                  final stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
                  final imageUrl = (data['imageUrl'] ?? '').toString();
                  final imageData = (data['imageData'] ?? '').toString();
                  return Card(
                    margin: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _saving ? null : () => _addProduct(doc),
                      child: Padding(
                        padding: const EdgeInsets.all(9),
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: imageData.isNotEmpty
                                    ? Image.memory(base64Decode(imageData), width: double.infinity, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(width: double.infinity, color: Colors.green.shade50,
                                          child: Icon(Icons.shopping_bag, size: 48, color: Colors.green.shade700)))
                                    : imageUrl.isEmpty
                                    ? Container(width: double.infinity, color: Colors.green.shade50,
                                        child: Icon(Icons.shopping_bag, size: 48, color: Colors.green.shade700))
                                    : Image.network(imageUrl, width: double.infinity, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(width: double.infinity,
                                          color: Colors.green.shade50,
                                          child: Icon(Icons.shopping_bag, size: 48, color: Colors.green.shade700))),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('Rs. ' + price.toStringAsFixed(2),
                                style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                            Text('තොගය ' + stock.toString(),
                                style: const TextStyle(color: Colors.grey, fontSize: 11)),
                            const SizedBox(height: 3),
                            SizedBox(width: double.infinity, height: 34,
                              child: FilledButton.icon(
                                onPressed: _saving ? null : () => _addProduct(doc),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Bill එකට'),
                              )),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }


  Widget _manualTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'භාණ්ඩ නම හෝ බාර්කෝඩ් සොයන්න...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: DropdownButtonFormField<String>(
            value: _manualCategory,
            decoration: InputDecoration(
              labelText: 'භාණ්ඩ වර්ගය තෝරන්න',
              prefixIcon: const Icon(Icons.category_outlined),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            items: supermarketCategories.map(
              (category) => DropdownMenuItem(value: category, child: Text(category)),
            ).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _manualCategory = value);
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 5, 14, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('සෙවුමට ගැලපෙන භාණ්ඩ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _myProductsQuery().snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('භාණ්ඩ ලැයිස්තුව ලබාගැනීමේදී දෝෂයක් ඇතිවුණා.'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data();
                final name = (data['name'] ?? '').toString().toLowerCase();
                final barcode = (data['barcode'] ?? '').toString().toLowerCase();
                final category = (data['category'] ?? '').toString();
                final matchesSearch = _searchQuery.isEmpty ||
                    name.contains(_searchQuery) ||
                    barcode.contains(_searchQuery);
                final matchesCategory = _manualCategory == 'සියලුම භාණ්ඩ' ||
                    category == _manualCategory;
                final stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
                return matchesSearch && matchesCategory && stock > 0;
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Text('ගැලපෙන භාණ්ඩ හමු වුණේ නැහැ.',
                      style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();
                  final name = (data['name'] ?? 'නම නැත').toString();
                  final barcode = (data['barcode'] ?? '').toString();
                  final category = (data['category'] ?? 'වෙනත්').toString();
                  final price = (data['sellingPrice'] as num?)?.toDouble() ?? 0;
                  final stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
                  final imageUrl = (data['imageUrl'] ?? '').toString();
                  final imageData = (data['imageData'] ?? '').toString();

                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      leading: imageData.isNotEmpty
                          ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(base64Decode(imageData), width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(width: 52, height: 52, color: Colors.green.shade50, child: Icon(Icons.shopping_bag, color: Colors.green.shade700))))
                          : imageUrl.isEmpty
                          ? Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.shopping_bag, color: Colors.green.shade700),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                imageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 52,
                                  height: 52,
                                  color: Colors.green.shade50,
                                  child: Icon(Icons.shopping_bag, color: Colors.green.shade700),
                                ),
                              ),
                            ),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Rs. ' + price.toStringAsFixed(2) +
                            '  •  තොගය $stock  •  ' + category +
                            (barcode.isEmpty ? '' : '\nබාර්කෝඩ්: $barcode'),
                      ),
                      isThreeLine: barcode.isNotEmpty,
                      trailing: IconButton(
                        tooltip: 'බිල්පතට එකතු කරන්න',
                        onPressed: _saving ? null : () => _addProduct(doc),
                        icon: const Icon(Icons.add_circle, color: Colors.green, size: 32),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🧾 අලුත් බිල්පත',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'බාර්කෝඩ්'),
              Tab(icon: Icon(Icons.search), text: 'Search'),
              Tab(icon: Icon(Icons.star), text: 'Quick Sale'),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.point_of_sale, color: Colors.white, size: 34),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('විකුණුම් බිල්පත',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        SizedBox(height: 3),
                        Text('බාර්කෝඩ් හෝ භාණ්ඩ සෙවුමෙන් ඉක්මනින් බිල්පත සකස් කරන්න',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('භාණ්ඩ', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      Text(_itemCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _barcodeTab(),
                  _manualTab(),
                  _quickSaleTab(),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('භාණ්ඩ ' + _items.length.toString() + 'ක් • ඒකක ' + _itemCount.toString(),
                            style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        const Text('මුළු මුදල',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('ගෙවිය යුතු මුදල',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Rs. ' + _total.toStringAsFixed(2),
                            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Colors.green.shade700)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _items.isEmpty || _saving ? null : _saveBill,
                        icon: _saving
                            ? const SizedBox(
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_alt),
                        label: Text(_saving ? 'බිල්පත සුරැකෙමින්...' : 'බිල්පත සුරකින්න',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillItem {
  _BillItem({
    required this.docId,
    required this.name,
    required this.barcode,
    required this.price,
    required this.quantity,
    required this.stock,
    required this.imageUrl,
    required this.imageData,
  });

  final String docId;
  final String name;
  final String barcode;
  final double price;
  int quantity;
  final int stock;
  final String imageUrl;
  final String imageData;

  double get total => price * quantity;
}

class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  bool _found = false;

  void _onDetect(BarcodeCapture capture) {
    if (_found) return;

    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _found = true;
        Navigator.of(context).pop(value.trim());
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('බාර්කෝඩ් ස්කෑන්'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            onDetect: _onDetect,
          ),
          Center(
            child: Container(
              width: 280,
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Text(
              'බාර්කෝඩ් එක කොටුව ඇතුළට තබන්න. ස්කෑන් වූ විගස බාර්කෝඩ් ක්ෂේත්‍රයට ඇතුළත් වේ.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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