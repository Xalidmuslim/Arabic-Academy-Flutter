import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../features/integrations/phone_auth_screen.dart';

class ReferenceWelcomeScreen extends StatelessWidget {
  const ReferenceWelcomeScreen({
    super.key,
    required this.onStart,
    this.backend,
  });
  final Future<void> Function() onStart;
  final BackendService? backend;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/artwork/hero.webp',
          cacheWidth: 1200,
          fit: BoxFit.cover,
          alignment: Alignment.centerRight,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x12FFF7E9), Color(0x7EFFF5E4), Color(0xECFFF6E8)],
              stops: [0, 0.52, 1],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 24, 26, 28),
            child: Column(
              children: [
                const Spacer(flex: 5),
                const Text(
                  'Байна Ядайк',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF073C30),
                    fontSize: 32,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    fontVariations: [FontVariation('wght', 800)],
                  ),
                ),
                const SizedBox(height: 17),
                const Text(
                  'العربية بين يديك',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: Color(0xFF234A3A),
                    fontSize: 30,
                    height: 1.8,
                  ),
                ),
                const Text(
                  'Арабский язык в твоих руках',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF293C35),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const Spacer(flex: 3),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF094D3A)),
                    SizedBox(width: 7),
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF9EB3A7)),
                    SizedBox(width: 7),
                    CircleAvatar(radius: 4, backgroundColor: Color(0xFF9EB3A7)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: () => onStart(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF073F32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Начать обучение',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontVariations: [FontVariation('wght', 800)],
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PhoneAuthScreen(backend: backend ?? BackendService()),
                    ),
                  ),
                  child: const Text(
                    'У меня уже есть аккаунт',
                    style: TextStyle(color: Color(0xFF183A2F), fontSize: 13),
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
