import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'XWXWX Admin',
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFFFF5252),
        secondary: const Color(0xFFFFC107),
        surface: const Color(0xFF1A1A2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
    ),
    home: const AdminHome(),
  );
}

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Row(children: [
          Icon(Icons.admin_panel_settings, color: Color(0xFFFF5252)),
          SizedBox(width: 8),
          Text('پنل مدیریت XWXWX'),
        ]),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users')
          .orderBy('lastUpdate', descending: true).snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(child: Text('هنوز کاربری ثبت‌نام نکرده', style: TextStyle(fontSize: 16, color: Colors.white60)));
          }
          final docs = snap.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final phone = d['phone'] ?? docs[i].id;
              final status = d['status'] ?? 'phone_entered';
              return _userTile(context, phone, status, d);
            },
          );
        },
      ),
    ),
  );

  Widget _userTile(BuildContext context, String phone, String status, Map<String, dynamic> data) {
    final info = _statusInfo(status);
    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: info.$2,
          child: Icon(info.$3, color: Colors.white, size: 20),
        ),
        title: Text(phone, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(info.$1, style: TextStyle(color: info.$2, fontSize: 13)),
        trailing: const Icon(Icons.arrow_back_ios, size: 16),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => UserDetail(phone: phone, data: data),
        )),
      ),
    );
  }

  (String, Color, IconData) _statusInfo(String s) {
    switch (s) {
      case 'phone_entered': return ('مرحله ۱: شماره وارد شده', Colors.orange, Icons.phone);
      case 'code_entered': return ('مرحله ۲: کد تأیید شد', Colors.blue, Icons.check);
      case 'waiting_password': return ('مرحله ۳: منتظر تعیین رمز', Colors.amber, Icons.lock_open);
      case 'waiting_approval': return ('مرحله ۴: منتظر تأیید تو', Colors.purple, Icons.hourglass_top);
      case 'active': return ('فعال ✅', Colors.green, Icons.verified_user);
      case 'blocked': return ('بلاک شده', Colors.red, Icons.block);
      default: return (s, Colors.grey, Icons.help);
    }
  }
}

class UserDetail extends StatefulWidget {
  final String phone;
  final Map<String, dynamic> data;
  const UserDetail({super.key, required this.phone, required this.data});
  @override
  State<UserDetail> createState() => _UserDetailState();
}

class _UserDetailState extends State<UserDetail> {
  late Stream<DocumentSnapshot> _stream;
  final _codeCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();
  String _mode = 'without_password';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance.collection('users').doc(widget.phone).snapshots();
    _mode = widget.data['passwordMode'] ?? 'without_password';
    _codeCtrl.text = widget.data['code']?.toString() ?? '';
    _hintCtrl.text = widget.data['passwordHint']?.toString() ?? '';
  }

  Future<void> _update(Map<String, dynamic> values) async {
    setState(() => _busy = true);
    try {
      values['lastUpdate'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance.collection('users').doc(widget.phone).update(values);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا: $e')));
    }
    setState(() => _busy = false);
  }

  Future<void> _sendCode() async {
    final c = _codeCtrl.text.trim();
    if (c.isEmpty) return;
    await _update({'code': c, 'status': 'code_sent'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد ذخیره شد ✅ کاربر باید وارد کنه')));
  }

  Future<void> _saveHint() async {
    await _update({'passwordHint': _hintCtrl.text.trim(), 'passwordMode': _mode});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تنظیمات ذخیره شد ✅')));
  }

  Future<void> _activate() async {
    await _update({'status': 'active'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کاربر فعال شد ✅')));
  }

  Future<void> _block() async {
    await _update({'status': 'blocked'});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کاربر بلاک شد')));
  }

  Future<void> _reset() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.phone).delete();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(widget.phone),
        actions: [
          IconButton(icon: const Icon(Icons.delete, color: Colors.redAccent), onPressed: _confirmReset),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final d = snap.data!.data() as Map<String, dynamic>? ?? {};
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _stageCard('مرحله ۱ — شماره وارد شد', d['phone'] != null),
              _stageCard('مرحله ۲ — کد تأیید', d['status'] == 'code_entered' || d['status'] == 'waiting_password' || d['status'] == 'waiting_approval' || d['status'] == 'active'),
              _stageCard('مرحله ۳ — تعیین رمز', d['status'] == 'waiting_approval' || d['status'] == 'active'),
              _stageCard('مرحله ۴ — تأیید نهایی', d['status'] == 'active'),
              const SizedBox(height: 20),
              const Divider(),
              const Text('🔐 ارسال کد به کاربر', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: InputDecoration(
                  hintText: '_____', filled: true, fillColor: const Color(0xFF1A1A2E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : _sendCode,
                icon: const Icon(Icons.send),
                label: const Text('ذخیره کد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text('🔑 حالت رمز', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              RadioListTile<String>(
                value: 'with_password', groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
                title: const Text('با رمز'),
                subtitle: const Text('کاربر باید رمز تعیین کنه'),
                activeColor: const Color(0xFFFFC107),
              ),
              RadioListTile<String>(
                value: 'without_password', groupValue: _mode,
                onChanged: (v) => setState(() => _mode = v!),
                title: const Text('بدون رمز'),
                subtitle: const Text('مستقیم وارد می‌شه'),
                activeColor: const Color(0xFFFFC107),
              ),
              if (_mode == 'with_password') ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _hintCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'راهنمای رمز...',
                    filled: true, fillColor: const Color(0xFF1A1A2E),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _busy ? null : _saveHint,
                icon: const Icon(Icons.save),
                label: const Text('ذخیره تنظیمات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const Text('✅ تأیید نهایی', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: _busy ? null : _activate,
                  icon: const Icon(Icons.check_circle),
                  label: const Text('فعال کن'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: ElevatedButton.icon(
                  onPressed: _busy ? null : _block,
                  icon: const Icon(Icons.block),
                  label: const Text('بلاک'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )),
              ]),
            ]),
          );
        },
      ),
    ),
  );

  Widget _stageCard(String title, bool done) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: done ? Colors.green : Colors.white24),
    ),
    child: Row(children: [
      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Colors.green : Colors.white38),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: TextStyle(
        color: done ? Colors.white : Colors.white54,
        fontWeight: done ? FontWeight.bold : FontWeight.normal,
      ))),
    ]),
  );

  void _confirmReset() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text('حذف کاربر؟'),
      content: const Text('اطلاعات کاربر کاملاً پاک می‌شه.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
        TextButton(onPressed: () { Navigator.pop(context); _reset(); }, child: const Text('حذف', style: TextStyle(color: Colors.red))),
      ],
    ));
  }
}
