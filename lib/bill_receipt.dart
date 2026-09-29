import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

class BillReceiptPage extends StatefulWidget {
  const BillReceiptPage({
    super.key,
    required this.billNumber,
    required this.dateKey,
    required this.items,
    required this.total,
  });

  final String billNumber;
  final String dateKey;
  final List<Map<String, dynamic>> items;
  final double total;

  @override
  State<BillReceiptPage> createState() => _BillReceiptPageState();
}

class _BillReceiptPageState extends State<BillReceiptPage> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _busy = false;

  String _formatDate() {
    final parts = widget.dateKey.split('-');
    if (parts.length == 3) {
      return parts[2] + '/' + parts[1] + '/' + parts[0];
    }
    return widget.dateKey;
  }

  int get _units => widget.items.fold<int>(
        0,
        (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 0),
      );

  Widget _receipt() {
    return Container(
      width: 380,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🏪 සුපිරි වෙළඳසැල',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'SUPERMARKET MANAGEMENT SYSTEM',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 1),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'විකුණුම් බිල්පත',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
                const SizedBox(height: 6),
                Text('බිල් අංකය: ' + widget.billNumber),
                Text('දිනය: ' + _formatDate()),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text('භාණ්ඩ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: 6),
              SizedBox(
                width: 45,
                child: Text('Qty', textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              SizedBox(
                width: 78,
                child: Text('මුදල', textAlign: TextAlign.right,
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(thickness: 1.4),
          ...widget.items.map((item) {
            final name = (item['name'] ?? '').toString();
            final qty = (item['quantity'] as num?)?.toInt() ?? 0;
            final price = (item['price'] as num?)?.toDouble() ?? 0;
            final lineTotal = (item['total'] as num?)?.toDouble() ?? price * qty;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Rs. ' + price.toStringAsFixed(2) + ' × ' + qty.toString(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 45,
                    child: Text(qty.toString(), textAlign: TextAlign.center),
                  ),
                  SizedBox(
                    width: 78,
                    child: Text(
                      'Rs. ' + lineTotal.toStringAsFixed(2),
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(thickness: 1.4),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('මුළු ඒකක', style: TextStyle(color: Colors.grey)),
              Text(_units.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ගෙවිය යුතු මුදල',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Rs. ' + widget.total.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.green.shade800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'ස්තුතියි! නැවතත් පැමිණෙන්න. ❤️',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Powered by SriHarsha Digital',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<Uint8List?> _capture() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      return await _screenshotController.capture(pixelRatio: 2.5);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('බිල්පත image එක සකස් කිරීමට නොහැකි වුණා: ' + e.toString())),
        );
      }
      return null;
    }
  }

  Future<void> _shareImage() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            name: 'bill_' + widget.billNumber + '.png',
            mimeType: 'image/png',
          ),
        ],
        text: 'සුපිරි වෙළඳසැල - බිල්පත ' + widget.billNumber,
        subject: 'විකුණුම් බිල්පත ' + widget.billNumber,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share කිරීමට නොහැකි වුණා: ' + e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printBill() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) return;

      final doc = pw.Document();
      final image = pw.MemoryImage(bytes);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            80 * PdfPageFormat.mm,
            220 * PdfPageFormat.mm,
            marginAll: 4 * PdfPageFormat.mm,
          ),
          build: (_) => pw.Center(
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );

      await Printing.layoutPdf(
        name: 'bill_' + widget.billNumber + '.pdf',
        onLayout: (_) async => doc.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Print කිරීමට නොහැකි වුණා: ' + e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        title: const Text('🧾 බිල්පත'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Image Share',
            onPressed: _busy ? null : _shareImage,
            icon: const Icon(Icons.share),
          ),
          IconButton(
            tooltip: 'Print',
            onPressed: _busy ? null : _printBill,
            icon: const Icon(Icons.print),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 20),
              child: Center(
                child: Screenshot(
                  controller: _screenshotController,
                  child: _receipt(),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _shareImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Image Share'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _printBill,
                      icon: const Icon(Icons.print),
                      label: const Text('Print'),
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
