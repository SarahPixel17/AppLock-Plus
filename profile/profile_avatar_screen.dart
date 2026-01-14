import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'avatar_provider.dart';

class ProfileAvatarScreen extends StatelessWidget {
  const ProfileAvatarScreen({super.key});

  static const _avatars = [
    'assets/avatars/defaultcat.png',
    'assets/avatars/catviolin.png',
    'assets/avatars/ladycat.png',
    'assets/avatars/bookcat.png',
    'assets/avatars/fox.png',
    'assets/avatars/rabbit.png',
    'assets/avatars/dog.png',
  ];

  @override
  Widget build(BuildContext context) {
    final selected = context.watch<AvatarProvider>().character;

    return Scaffold(
      backgroundColor: const Color(0xFFF9E9D2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9E9D2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF936B46)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile Avatar',
          style: TextStyle(fontSize: 28, color: Color(0xFF553F2B)),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose Avatar',
              style: TextStyle(fontSize: 22, color: Color(0xFF553F2B)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.builder(
                itemCount: _avatars.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemBuilder: (_, i) {
                  final path = _avatars[i];
                  final isSel = path.contains(selected);

                  return GestureDetector(
                    onTap: () {
                      final provider = context.read<AvatarProvider>();

                      // Extract character name from file path
                      final characterName = path.split('/').last.split('.').first;

                      // Reset to neutral expression for new avatar
                      provider.setCharacter(characterName);
                      provider.setExpression(CatExpression.neutral);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSel ? const Color(0xFF936B46) : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(path, fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
