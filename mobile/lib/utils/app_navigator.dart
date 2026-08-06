import 'package:flutter/material.dart';

// FCM 포그라운드 메시지 같이 위젯 트리 밖(서비스 클래스)에서 배너/다이얼로그를
// 띄워야 할 때 쓰는 전역 네비게이터 키. MaterialApp(navigatorKey: appNavigatorKey)에
// 연결해서, 어디서든 appNavigatorKey.currentContext로 살아있는 BuildContext를 얻는다.
final appNavigatorKey = GlobalKey<NavigatorState>();
