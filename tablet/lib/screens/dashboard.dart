import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sidebarx/sidebarx.dart';

class DashboardScreen extends HookConsumerWidget {
  DashboardScreen({super.key});

  final _controller = SidebarXController(selectedIndex: 0, extended: false);
  final _searchController = TextEditingController();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      drawer: CustomSidebar(controller: _controller),
      appBar: AppBar(
        title: Row(
          children: [
            Text('분석 목록'),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(10)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        actions: [
          ElevatedButton(
            onPressed: () {},
            child: Row(children: [Icon(Icons.add), Text('새 분석')]),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.grey,
              child: ListView.separated(
                itemBuilder: (context, index) {},
                separatorBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    child: ListTile(title: Text('홍길동')),
                  );
                },
                itemCount: 3,
              ),
            ),
          ),
          Divider(thickness: 2, height: 2),
          Expanded(
            flex: 6,
            child: Container(
              color: Colors.amber,
              child: Center(child: Text('Simple Result')),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomSidebar extends StatelessWidget {
  // 메인 화면에서 컨트롤러를 전달받아 상태를 동기화합니다.
  final SidebarXController controller;

  const CustomSidebar({Key? key, required this.controller}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SidebarX(
      controller: controller,
      theme: SidebarXTheme(
        width: 80, // Drawer 공간에 맞춰 살짝 넓게 지정
        // Drawer 자체 여백과 겹치지 않도록 마진 조정 (위아래만 여백 적용)
        margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xff1f1f3a),
          borderRadius: BorderRadius.circular(16),
        ),
        iconTheme: const IconThemeData(color: Colors.white70, size: 22),
        selectedIconTheme: const IconThemeData(color: Colors.white, size: 24),
        selectedItemDecoration: BoxDecoration(
          color: const Color(0xff2d2d54),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // 확장을 완전히 차단하기 위해 너비를 동일하게 고정
      extendedTheme: const SidebarXTheme(width: 80),
      headerBuilder: (context, extended) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: CircleAvatar(
            radius: 20,
            backgroundColor: Colors.orange,
            child: Icon(Icons.person, color: Colors.white),
          ),
        );
      },
      items: const [
        SidebarXItem(icon: Icons.home),
        SidebarXItem(icon: Icons.search),
        SidebarXItem(icon: Icons.people),
        SidebarXItem(icon: Icons.favorite),
      ],
    );
  }
}
