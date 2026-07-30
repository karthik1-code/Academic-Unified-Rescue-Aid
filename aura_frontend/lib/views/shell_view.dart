import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aura_frontend/core/theme.dart';

class AppShellView extends StatelessWidget {
  final Widget child;
  const AppShellView({Key? key, required this.child}) : super(key: key);

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/attendance')) return 1;
    if (location.startsWith('/chat')) return 2;
    if (location.startsWith('/syllabus')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/dashboard');
        break;
      case 1:
        context.go('/attendance');
        break;
      case 2:
        context.go('/chat');
        break;
      case 3:
        context.go('/syllabus');
        break;
      case 4:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _calculateSelectedIndex(context);
    
    return Scaffold(
      backgroundColor: AuraColors.background,
      body: Stack(
        children: [
          // Background Aurora Glow
          Positioned(
            top: -200,
            right: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AuraColors.accent.withOpacity(0.15),
                    blurRadius: 150,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            left: -200,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AuraColors.primary.withOpacity(0.08),
                    blurRadius: 150,
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AuraColors.cardBorder.withOpacity(0.15),
              width: 1.5
            )
          ),
          color: AuraColors.background.withOpacity(0.95),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) => _onItemTapped(index, context),
          backgroundColor: Colors.transparent,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AuraColors.primary,
          unselectedItemColor: AuraColors.textMuted,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard, color: AuraColors.primary),
              label: 'Dashboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today, color: AuraColors.primary),
              label: 'Calendar',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AuraColors.auroraGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AuraColors.primary,
                      blurRadius: 10,
                      spreadRadius: -2,
                    )
                  ]
                ),
                child: const Icon(Icons.psychology, color: Colors.white, size: 28),
              ),
              label: 'Aura AI',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.book_outlined),
              activeIcon: Icon(Icons.book, color: AuraColors.primary),
              label: 'Syllabus',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person, color: AuraColors.primary),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
