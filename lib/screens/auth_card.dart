import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/icons.dart';
import '../core/theme/tokens.dart';
import '../providers/core_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_card.dart';
import '../widgets/toast.dart';

/// Form masuk / daftar (kartu Akun untuk tamu).
class AuthCard extends ConsumerStatefulWidget {
  const AuthCard({super.key});
  @override
  ConsumerState<AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends ConsumerState<AuthCard> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _register = false;
  bool _show = false;

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final u = _user.text.trim();
    final p = _pass.text;
    if (u.isEmpty || p.isEmpty) {
      showToast(context, 'Username dan password wajib diisi.');
      return;
    }
    final err = await ref.read(authProvider.notifier).signIn(u, p, register: _register);
    if (!mounted) return;
    if (err != null) {
      showToast(context, err);
    } else {
      showToast(context, _register ? 'Akun berhasil dibuat.' : 'Berhasil masuk.');
    }
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: T.ink4, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: const Color.fromRGBO(255, 255, 255, .78),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        suffixIcon: suffix,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd), borderSide: const BorderSide(color: T.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(T.rMd),
            borderSide: const BorderSide(color: T.accent)),
      );

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(authProvider.select((s) => s.busy));
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _Seg(label: 'Masuk', active: !_register, onTap: () => setState(() => _register = false))),
              const SizedBox(width: 8),
              Expanded(child: _Seg(label: 'Daftar', active: _register, onTap: () => setState(() => _register = true))),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _user,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 16, color: T.ink, fontWeight: FontWeight.w600),
            decoration: _dec('Username'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            obscureText: !_show,
            autocorrect: false,
            enableSuggestions: false,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 16, color: T.ink, fontWeight: FontWeight.w600),
            decoration: _dec(
              'Password',
              suffix: IconButton(
                icon: Icon(_show ? AppIcons.eyeOff : AppIcons.eye, size: 20, color: T.ink3),
                onPressed: () => setState(() => _show = !_show),
              ),
            ),
          ),
          if (_register)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Username 3–24 karakter (huruf, angka, titik, underscore). Password minimal 8 karakter.',
                  style: TextStyle(fontSize: 11.5, color: T.ink3, fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 14),
          PrimaryButton(label: _register ? 'Buat akun' : 'Masuk', busy: busy, onPressed: _submit),
        ],
      ),
    );
  }
}

class _Seg extends StatelessWidget {
  const _Seg({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: T.dur,
        curve: T.ease,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? T.accent : T.glass,
          borderRadius: BorderRadius.circular(T.rPill),
          border: Border.all(color: active ? T.accent : T.glassEdge),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: active ? Colors.white : T.ink2)),
      ),
    );
  }
}
