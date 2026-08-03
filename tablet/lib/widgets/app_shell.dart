import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/router/routes.dart';

class AppShell extends HookWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // 위치 기억, 현재 주소에서 이동한 탭을 역산
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _tabIndexOf(location);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.sage400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: NavigationRail(
                  backgroundColor: Colors.transparent,
                  selectedIndex: selected,
                  onDestinationSelected: (i) => context.go(_tabRoutes[i]),
                  leading: Column(
                    children: [
                      const SizedBox(height: AppDimens.gapLg),
                      const SizedBox(height: AppDimens.gapLg),
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.brand,
                        child: Icon(Icons.person, color: AppColors.onBrand),
                      ),
                      const SizedBox(height: AppDimens.gapXl),
                    ],
                  ),
                  trailing: Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppDimens.gapXl),
                        child: IconButton(
                          tooltip: '로그아웃',
                          icon: const Icon(Icons.logout),
                          onPressed: () => context.go(Routes.login),
                        ),
                      ),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      label: Text('대시보드'),
                      selectedIcon: Icon(Icons.grid_view),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.upload_file_outlined),
                      label: Text('업로드'),
                      selectedIcon: Icon(Icons.upload_file),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.assessment_outlined),
                      label: Text('결과'),
                      selectedIcon: Icon(Icons.assessment),
                    ),
                  ],
                ),
              ),
            ),
            // const VerticalDivider(width: 1),
            // 내용
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

const _tabRoutes = [Routes.dashboard, Routes.upload, Routes.results];

int _tabIndexOf(String location) {
  if (location.startsWith(Routes.upload)) return 1;
  if (location.startsWith(Routes.results) ||
      location.startsWith(Routes.resultDetail)) {
    return 2;
  }
  return 0;
}
