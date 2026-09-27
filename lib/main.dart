import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'firebase_options.dart';

const List<String> supermarketCategories = [
  'සියලුම භාණ්ඩ',
  'ආහාර ද්‍රව්‍ය',
  'බීම වර්ග',
  'ස්නැක්ස් හා බිස්කට්',
  'කිරි හා ශීත කළ',
  'ගෘහස්ථ භාණ්ඩ',
  'පෞද්ගලික සත්කාර',
  'ළදරු භාණ්ඩ',
  'ලිපි ද්‍රව්‍ය',
  'වෙනත්',
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SupermarketApp());
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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
        title: const Text(
          '🏪 සුපිරි වෙළඳසැල',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'නිර්මාණය: Srimal Harsha',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),
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
                    onTap: () {},
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
            const SizedBox(height: 20),
            const Text(
              '📊 අද තත්ත්වය',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.shopping_cart,
                    title: 'අද විකුණුම්',
                    value: '0',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    icon: Icons.attach_money,
                    title: 'මුළු ආදායම',
                    value: 'Rs. 0',
                  ),
                ),
              ],
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
            const Center(
              child: Text(
                'Supermarket Management System',
                style: TextStyle(color: Colors.grey, fontSize: 13),
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

  Future<void> _editProduct(DocumentSnapshot<Map<String, dynamic>> doc) async {
    final data = doc.data() ?? {};
    final nameController = TextEditingController(text: (data['name'] ?? '').toString());
    final barcodeController = TextEditingController(text: (data['barcode'] ?? '').toString());
    final buyController = TextEditingController(text: (data['buyPrice'] ?? '').toString());
    final sellController = TextEditingController(text: (data['sellingPrice'] ?? '').toString());
    final stockController = TextEditingController(text: (data['stockQuantity'] ?? 0).toString());
    final limitController = TextEditingController(text: (data['lowStockLimit'] ?? 5).toString());
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
        stream: FirebaseFirestore.instance
            .collection('products')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('භාණ්ඩ තොග දත්ත ලබාගැනීමේදී දෝෂයක් ඇතිවුණා.'),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
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

          return Column(
            children: [
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
                          final isOut = quantity <= 0;
                          final isLow = quantity > 0 && quantity <= limit;
                          final statusColor = isOut
                              ? Colors.red
                              : (isLow ? Colors.orange : Colors.green);

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor:
                                    statusColor.withValues(alpha: 0.12),
                                child: Icon(
                                  isOut
                                      ? Icons.remove_shopping_cart
                                      : Icons.inventory_2,
                                  color: statusColor,
                                ),
                              ),
                              title: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text([
                                  if (category.isNotEmpty)
                                    'වර්ගය: $category',
                                  if (barcode.isNotEmpty)
                                    'බාර්කෝඩ්: $barcode',
                                  'විකුණුම් මිල: රු. ${sellingPrice.toStringAsFixed(2)}',
                                ].join('\n')),
                              ),
                              trailing: SizedBox(
                                width: 145,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          '$quantity',
                                          style: TextStyle(
                                            fontSize: 21,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Icon(
                                          isOut
                                              ? Icons.remove_shopping_cart
                                              : Icons.inventory_2,
                                          size: 18,
                                          color: statusColor,
                                        ),
                                      ],
                                    ),
                                    Text(
                                      isOut
                                          ? 'තොග අවසන්'
                                          : (isLow ? 'අඩු තොග' : 'තොග තිබේ'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        IconButton(
                                          tooltip: 'සංස්කරණය කරන්න',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.edit, size: 21),
                                          color: Colors.blue,
                                          onPressed: () => _editProduct(filteredDocs[index]),
                                        ),
                                        IconButton(
                                          tooltip: 'මකන්න',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          icon: const Icon(Icons.delete, size: 21),
                                          color: Colors.red,
                                          onPressed: () => _deleteProduct(filteredDocs[index], name),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController(text: '5');

  bool _saving = false;

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

  Future<void> _fillProductFromBarcode(String barcode) async {
    setState(() {
      _barcodeController.text = barcode;
    });

    // 1. First check our own supermarket database.
    try {
      final result = await FirebaseFirestore.instance
          .collection('products')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get();

      if (!mounted) return;

      if (result.docs.isNotEmpty) {
        final data = result.docs.first.data();

        setState(() {
          _nameController.text = (data['name'] ?? '').toString();
          final savedCategory = (data['category'] ?? '').toString();
          _categoryController.text =
              _isAllowedCategory(savedCategory) ? savedCategory : 'වෙනත්';
          _buyPriceController.text = (data['buyPrice'] ?? '').toString();
          _sellingPriceController.text =
              (data['sellingPrice'] ?? '').toString();
        });

        _showMessage('අපේ තොග දත්ත වලින් විස්තර ස්වයංක්‍රීයව පුරවා ගත්තා.');
        return;
      }
    } catch (_) {
      // If Firestore lookup fails, continue to the public barcode database.
    }

    // 2. If it is not in our database, look up the barcode in Open Food Facts.
    try {
      final uri = Uri.https(
        'world.openfoodfacts.org',
        '/api/v3/product/$barcode',
        <String, String>{
          'product_type': 'all',
          'fields': 'product_name,categories,brands',
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
          final brand = (product['brands'] ?? '').toString().trim();

          if (name.isNotEmpty || categories.isNotEmpty) {
            setState(() {
              if (name.isNotEmpty) {
                _nameController.text = name;
              }
              if (categories.isNotEmpty) {
                final onlineCategory = categories.split(',').first.trim();
                _categoryController.text =
                    _isAllowedCategory(onlineCategory) ? onlineCategory : 'වෙනත්';
              } else if (brand.isNotEmpty) {
                _categoryController.text = 'වෙනත්';
              }
            });

            _showMessage(
              'අන්තර්ජාල බාර්කෝඩ් දත්ත ගබඩාවෙන් භාණ්ඩ නම සහ වර්ගය ස්වයංක්‍රීයව පුරවා ගත්තා. මිලදී ගැනීමේ සහ විකුණුම් මිල අපේ වෙළඳසැලට අදාළ නිසා ඔබ ඇතුළත් කරන්න.',
            );
            return;
          }
        }
      }

      _showMessage(
        'මේ බාර්කෝඩ් එක පොදු භාණ්ඩ දත්ත ගබඩාවේ හමු වුණේ නැහැ. විස්තර අතින් ඇතුළත් කරන්න.',
      );
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        'අන්තර්ජාල බාර්කෝඩ් දත්ත ගබඩාවට සම්බන්ධ වීමට බැරි වුණා. විස්තර අතින් ඇතුළත් කරන්න.',
        isError: true,
      );
    }
  }

  Future<void> _saveProduct() async {
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

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('products').add({
        'name': _nameController.text.trim(),
        'barcode': _barcodeController.text.trim(),
        'category': _categoryController.text.trim(),
        'buyPrice': buyPrice,
        'sellingPrice': sellingPrice,
        'stockQuantity': stock,
        'lowStockLimit': lowStock,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('භාණ්ඩය සාර්ථකව සුරැකුවා.');
      _formKey.currentState!.reset();
      _nameController.clear();
      _barcodeController.clear();
      _categoryController.clear();
      _buyPriceController.clear();
      _sellingPriceController.clear();
      _stockController.clear();
      _lowStockController.text = '5';
    } catch (e) {
      if (!mounted) return;
      _showMessage('භාණ්ඩය සුරැකීමේදී දෝෂයක් ඇතිවුණා.', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'අලුත් භාණ්ඩ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
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
              controller: _lowStockController,
              label: 'අඩු තොග සීමාව',
              icon: Icons.warning_amber_outlined,
              keyboardType: TextInputType.number,
              validator: _integer,
            ),
            const SizedBox(height: 6),
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
      ),
    );
  }
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
