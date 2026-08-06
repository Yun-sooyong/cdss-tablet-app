abstract final class Routes {
  static const splash = '/splash';
  static const login = '/login';

  static const dashboard = '/dashboard';
  static const upload = '/upload';
  static const chat = '/chat';
  static const qr = '/qr';
  static const notifications = '/notifications';

  // 대시보드와 형제 등록
  static const batchPath = '$dashboard/:batchId';
  static const reportSegment = 'report';

  // 이동용
  static String batch(String batchId) => '$dashboard/$batchId';
  static String batchReport(String batchId) => '$dashboard/$batchId/report';
}
