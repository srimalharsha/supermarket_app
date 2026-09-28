import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});
  @override State<PurchasePage> createState() => _PurchasePageState();
}
class _PurchasePageState extends State<PurchasePage> {
  final supplier = TextEditingController();
  final invoice = TextEditingController();
  final search = TextEditingController();
  String query = ''; bool saving = false;
  final items = <_PurchaseItem>[];
  double get total => items.fold(0, (s, e) => s + e.total);
  @override void dispose(){ supplier.dispose(); invoice.dispose(); search.dispose(); super.dispose(); }
  void add(DocumentSnapshot<Map<String,dynamic>> doc){
    final d=doc.data()??{}; final i=items.indexWhere((x)=>x.id==doc.id);
    setState((){ if(i>=0){items[i].qty++;} else {items.add(_PurchaseItem(doc.id,(d['name']??'නම නැත').toString(),(d['barcode']??'').toString(),(d['buyPrice'] as num?)?.toDouble()??0,1));} });
  }
  Future<void> save() async {
    if(items.isEmpty){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('භාණ්ඩයක් තෝරන්න.')));return;}
    setState(()=>saving=true); final db=FirebaseFirestore.instance; final ref=db.collection('purchases').doc();
    try { await db.runTransaction((tx) async {
      for(final x in items){ final p=db.collection('products').doc(x.id); final snap=await tx.get(p); if(!snap.exists) throw Exception('${x.name} හමු වුණේ නැහැ.'); final d=snap.data()??{}; final stock=(d['stockQuantity'] as num?)?.toInt()??0; tx.update(p,{'stockQuantity':stock+x.qty,'buyPrice':x.price,'updatedAt':FieldValue.serverTimestamp()}); }
      tx.set(ref,{'purchaseNumber':ref.id,'supplier':supplier.text.trim(),'invoiceNumber':invoice.text.trim(),'dateKey':DateTime.now().toIso8601String().substring(0,10),'total':total,'items':items.map((x)=>{'productId':x.id,'name':x.name,'barcode':x.barcode,'quantity':x.qty,'buyPrice':x.price,'total':x.total}).toList(),'createdAt':FieldValue.serverTimestamp()});
    }); if(!mounted)return; setState(()=>saving=false); items.clear(); supplier.clear(); invoice.clear(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('🛒 Purchase සුරැකුණා. Stock එක වැඩි කළා.')));
    } catch(e){if(mounted){setState(()=>saving=false);ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Purchase save දෝෂය: $e')));}}
  }
  @override Widget build(BuildContext context){ return Scaffold(appBar:AppBar(title:const Text('🛒 භාණ්ඩ මිලදී ගැනීම්'),centerTitle:true),body:Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:TextField(controller:supplier,decoration:const InputDecoration(labelText:'Supplier නම',border:OutlineInputBorder()))),const SizedBox(width:8),Expanded(child:TextField(controller:invoice,decoration:const InputDecoration(labelText:'Invoice No.',border:OutlineInputBorder())))])),
    Padding(padding:const EdgeInsets.fromLTRB(12,0,12,8),child:TextField(controller:search,onChanged:(v)=>setState(()=>query=v.trim().toLowerCase()),decoration:const InputDecoration(hintText:'භාණ්ඩ නම හෝ බාර්කෝඩ් සොයන්න...',prefixIcon:Icon(Icons.search),border:OutlineInputBorder()))),
    Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FirebaseFirestore.instance.collection('products').snapshots(),builder:(c,s){if(!s.hasData)return const Center(child:CircularProgressIndicator()); final docs=s.data!.docs.where((doc){final d=doc.data();final n=(d['name']??'').toString().toLowerCase();final b=(d['barcode']??'').toString().toLowerCase();return query.isEmpty||n.contains(query)||b.contains(query);}).toList(); if(docs.isEmpty)return const Center(child:Text('භාණ්ඩ හමු වුණේ නැහැ.')); return ListView.builder(padding:const EdgeInsets.all(12),itemCount:docs.length,itemBuilder:(c,i){final d=docs[i].data();final p=(d['buyPrice'] as num?)?.toDouble()??0;final st=(d['stockQuantity'] as num?)?.toInt()??0;return Card(child:ListTile(title:Text((d['name']??'නම නැත').toString()),subtitle:Text('Buy: Rs. '+p.toStringAsFixed(2)+' • Current stock: '+st.toString()),trailing:IconButton(icon:const Icon(Icons.add_circle,color:Colors.green,size:32),onPressed:()=>add(docs[i]))));});})),
    if(items.isNotEmpty)Container(constraints:const BoxConstraints(maxHeight:230),padding:const EdgeInsets.all(8),color:Colors.white,child:ListView.builder(itemCount:items.length,itemBuilder:(c,i){final x=items[i];return ListTile(title:Text(x.name),subtitle:Text('Rs. '+x.price.toStringAsFixed(2)+' × '+x.qty.toString()+' = Rs. '+x.total.toStringAsFixed(2)),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>setState(()=>x.qty>1?x.qty--:null),icon:const Icon(Icons.remove_circle_outline)),Text(x.qty.toString()),IconButton(onPressed:()=>setState(()=>x.qty++),icon:const Icon(Icons.add_circle_outline)),IconButton(onPressed:()=>setState(()=>items.removeAt(i)),icon:const Icon(Icons.delete_outline,color:Colors.red))]));})),
    Container(padding:const EdgeInsets.all(14),color:Colors.white,child:Row(children:[Expanded(child:Text('මුළු Purchase: Rs. '+total.toStringAsFixed(2),style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16))),FilledButton.icon(onPressed:saving?null:save,icon:const Icon(Icons.save),label:Text(saving?'සුරැකෙමින්...':'Purchase Save'))]))
  ])); }
}
class _PurchaseItem { _PurchaseItem(this.id,this.name,this.barcode,this.price,this.qty); final String id,name,barcode; double price; int qty; double get total=>price*qty; }