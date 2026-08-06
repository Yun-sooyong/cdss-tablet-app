import 'package:flutter/material.dart';

/// 채팅은 Django DB가 아니라 Firestore에 클라이언트가 직접 쓴다.
/// POST /api/v1/chat/firebase-token/ 으로 커스텀 토큰을 받아
/// signInWithCustomToken() 한 뒤 Firestore를 읽고 쓰는 구조.
/// firebase_core·firebase_auth·cloud_firestore 추가와 docs/CHAT_INTERFACE.md 가 필요하다.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('채팅 준비 중'));
  }
}
