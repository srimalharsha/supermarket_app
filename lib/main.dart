import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
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
            const SizedBox(height: 20),
            const Text(
              '📊 අද තත්ත්වය',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('dailySales')
                  .doc(DateTime.now().toIso8601String().substring(0, 10))
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? {};
                final bills = (data['billCount'] as num?)?.toInt() ?? 0;
                final revenue = (data['revenue'] as num?)?.toDouble() ?? 0;
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

  bool _isAllowedCategory(String value) {
    return supermarketCategories.skip(1).contains(value);
  }


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
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor:
                                            statusColor.withValues(alpha: 0.12),
                                        child: Icon(
                                          isOut
                                              ? Icons.remove_shopping_cart
                                              : Icons.inventory_2,
                                          color: statusColor,
                                        ),
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
      final result = await FirebaseFirestore.instance
          .collection('products')
          .where('barcode', isEqualTo: scannedBarcode)
          .limit(1)
          .get();

      if (!mounted) return;

      if (result.docs.isNotEmpty) {
        final data = result.docs.first.data();

        setState(() {
          _imageUrl = (data['imageUrl'] ?? '').toString();
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
        'imageUrl': _imageUrl.trim(),
        'barcode': _barcodeController.text.trim(),
        'category': _categoryController.text.trim(),
        'buyPrice': buyPrice,
        'sellingPrice': sellingPrice,
        'stockQuantity': stock,
        'lowStockLimit': lowStock,
        'expiryDate': _expiryDateController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('භාණ්ඩය සාර්ථකව සුරැකුවා.');
      _formKey.currentState!.reset();
      _nameController.clear();
      _barcodeController.clear();
      _imageUrl = '';
      _categoryController.clear();
      _buyPriceController.clear();
      _sellingPriceController.clear();
      _stockController.clear();
      _lowStockController.text = '5';
      _expiryDateController.clear();
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
            const SizedBox(height: 6),
            if (_imageUrl.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  _imageUrl,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 12),
            ],
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


class NewBillPage extends StatefulWidget {
  const NewBillPage({super.key});
  @override
  State<NewBillPage> createState() => _NewBillPageState();
}

class _NewBillPageState extends State<NewBillPage> {
  final List<_BillItem> _items = [];
  bool _saving = false;

  double get _total => _items.fold(0, (sum, item) => sum + item.total);

  String get _todayKey => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> _scanAndAdd() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (!mounted || code == null || code.trim().isEmpty) return;

    final barcode = code.trim();
    final snapshot = await FirebaseFirestore.instance
        .collection('products')
        .where('barcode', isEqualTo: barcode)
        .limit(1)
        .get();

    if (!mounted) return;
    if (snapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'මෙම බාර්කෝඩ් එකට භාණ්ඩයක් හමු වුණේ නැහැ. මුලින් භාණ්ඩය තොගයට එකතු කරන්න.',
        )),
      );
      return;
    }

    final doc = snapshot.docs.first;
    final data = doc.data();
    final name = (data['name'] ?? 'නම නොමැත').toString();
    final price = (data['sellingPrice'] as num?)?.toDouble() ?? 0;
    final stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
    final imageUrl = (data['imageUrl'] ?? '').toString();

    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(name + ' සඳහා විකිණුම් මිලක් නැහැ.')),
      );
      return;
    }

    final existingIndex = _items.indexWhere((item) => item.docId == doc.id);
    final currentQty =
        existingIndex >= 0 ? _items[existingIndex].quantity : 0;

    if (currentQty + 1 > stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(name + ' සඳහා තිබෙන තොගය ' + stock.toString() + ' යි.')),
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
        ));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(name + ' බිල්පතට එකතු කළා.')),
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
        SnackBar(content: Text(item.name + ' සඳහා තිබෙන තොගය ' +
            item.stock.toString() + ' යි.')),
      );
      return;
    }
    setState(() => item.quantity = newQty);
  }

  Future<void> _saveBill() async {
    if (_items.isEmpty || _saving) return;
    setState(() => _saving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final billRef = firestore.collection('bills').doc();
      final salesRef = firestore.collection('dailySales').doc(_todayKey);

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
          final currentStock =
              (data['stockQuantity'] as num?)?.toInt() ?? 0;

          if (currentStock < item.quantity) {
            throw Exception(item.name + ' සඳහා ප්‍රමාණවත් තොගයක් නැහැ. දැන් තිබෙන්නේ ' +
                currentStock.toString() + ' යි.');
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
        }).toList();

        transaction.set(billRef, {
          'billNumber': billRef.id,
          'items': billItems,
          'total': _total,
          'createdAt': FieldValue.serverTimestamp(),
          'dateKey': _todayKey,
        });

        transaction.set(
          salesRef,
          {
            'dateKey': _todayKey,
            'billCount': FieldValue.increment(1),
            'revenue': FieldValue.increment(_total),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return;
      final savedTotal = _total;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('බිල්පත සාර්ථකයි ✅'),
          content: Text(
            'මුළු මුදල: Rs. ' + savedTotal.toStringAsFixed(2) +
            '\nඅද ආදායමටත් එකතු කළා.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('හරි'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('බිල්පත සුරැකීමට නොහැකි වුණා: ' +
              e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('අලුත් බිල්පත')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton.icon(
                onPressed: _saving ? null : _scanAndAdd,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('බාර්කෝඩ් ස්කෑන් කර භාණ්ඩය එකතු කරන්න'),
              ),
            ),
          ),
          Expanded(
            child: _items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long, size: 70, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'බිල්පත හිස්.\nබාර්කෝඩ් එකක් ස්කෑන් කරන්න.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              if (item.imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    item.imageUrl,
                                    width: 58,
                                    height: 58,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        const Icon(Icons.shopping_bag, size: 42),
                                  ),
                                )
                              else
                                const SizedBox(
                                  width: 58,
                                  height: 58,
                                  child: Icon(Icons.shopping_bag, size: 42),
                                ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        )),
                                    Text('Rs. ' + item.price.toStringAsFixed(2)),
                                    Text('එකතුව: Rs. ' +
                                        item.total.toStringAsFixed(2),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        )),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: () => _changeQuantity(index, -1),
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text(item.quantity.toString(),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      )),
                                  IconButton(
                                    onPressed: () => _changeQuantity(index, 1),
                                    icon: const Icon(Icons.add_circle_outline),
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
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
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
                      const Text('මුළු බිල්පත් මුදල',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                      Text('Rs. ' + _total.toStringAsFixed(2),
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _items.isEmpty || _saving ? null : _saveBill,
                      icon: _saving
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_saving
                          ? 'බිල්පත සුරැකෙමින්...'
                          : 'බිල්පත සම්පූර්ණ කරන්න'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
  });

  final String docId;
  final String name;
  final String barcode;
  final double price;
  int quantity;
  final int stock;
  final String imageUrl;

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
