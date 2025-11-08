import 'package:flutter/material.dart';
import 'home_screen.dart';

class SignupScreen extends StatefulWidget {
  static const routeName = '/signup';
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.pushReplacementNamed(context, HomeScreen.routeName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text('Kayıt ol'), backgroundColor: color),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(decoration: InputDecoration(labelText: 'E-posta', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), controller: _email, validator: (v) => (v == null || v.isEmpty) ? 'E-posta girin' : null),
                    const SizedBox(height: 12),
                    TextFormField(decoration: InputDecoration(labelText: 'Şifre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), controller: _pass, obscureText: true, validator: (v) => (v == null || v.isEmpty) ? 'Şifre girin' : null),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: _submit,
                      style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(color),
                        foregroundColor: const WidgetStatePropertyAll(Colors.white),
                        minimumSize: const WidgetStatePropertyAll(Size.fromHeight(48)),
                        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      child: const Text('Kayıt ol'),
                    )
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
