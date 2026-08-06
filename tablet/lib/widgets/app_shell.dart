import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/providers/auth_provider.dart';
import 'package:tablet/providers/notification_provider.dart';
import 'package:tablet/router/routes.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 위치 기억, 현재 주소에서 이동한 탭을 역산
    final location = GoRouterState.of(context).matchedLocation;
    final selected = _tabIndexOf(location);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              // 여기서 Navigation 모양, 색 조절
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: NavigationRailTheme(
                  data: NavigationRailThemeData(
                    backgroundColor: Colors.transparent,
                    indicatorShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                    ),
                  ),
                  child: NavigationRail(
                    labelType: NavigationRailLabelType.all,
                    selectedIndex: selected,
                    onDestinationSelected: (i) => context.go(_tabRoutes[i]),
                    leading: Column(
                      children: [
                        const SizedBox(height: AppDimens.gapLg),
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: cs.primary,
                          child: Icon(Icons.person, color: cs.onPrimary),
                        ),
                        const SizedBox(height: AppDimens.gapXl),
                      ],
                    ),
                    trailing: Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppDimens.gapXl,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _NotificationBell(
                                selected: location.startsWith(
                                  Routes.notifications,
                                ),
                              ),
                              const SizedBox(height: AppDimens.gapLg),
                              IconButton(
                                tooltip: '로그아웃',
                                icon: const Icon(Icons.logout),
                                onPressed: () =>
                                    ref.read(authProvider.notifier).logout(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    destinations: [
                      NavigationRailDestination(
                        icon: Icon(Icons.grid_view_outlined),
                        label: Text('대시보드'),
                        selectedIcon: Icon(Icons.grid_view),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.add_box_outlined),
                        label: Text('새 분석'),
                        selectedIcon: Icon(Icons.add_box),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.qr_code_2_outlined),
                        label: Text('QR'),
                        selectedIcon: Icon(Icons.qr_code_2),
                      ),
                    ],
                  ),
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

/// 안읽음 개수를 배지로 얹은 알림 버튼.
/// 탭이 아니라 하단 고정이라 NavigationRailDestination 이 아니다.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 99 ? '99+' : '$unread'),
          child: IconButton(
            tooltip: '알림',
            isSelected: selected,
            icon: const Icon(Icons.notifications_none),
            selectedIcon: const Icon(Icons.notifications),
            onPressed: () => context.go(Routes.notifications),
          ),
        ),
      ],
    );
  }
}

const _tabRoutes = [Routes.dashboard, Routes.upload, Routes.qr];

/// 대시보드의 `+ 새 분석` 버튼도 같은 /upload 로 간다 — 두 경로 모두 남긴다.
int? _tabIndexOf(String location) {
  if (location.startsWith(Routes.dashboard)) return 0;
  if (location.startsWith(Routes.upload)) return 1;
  if (location.startsWith(Routes.qr)) return 2;
  return null; // /notifications 등 탭이 아닌 화면
}
