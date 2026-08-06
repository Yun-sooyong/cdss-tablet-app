/// VitaTree 공용 테마. mobile·tablet이 같이 쓴다.
///
/// ```dart
/// import 'package:shared/theme/theme.dart';
///
/// MaterialApp(
///   theme: AppTheme.light,
///   darkTheme: AppTheme.dark,
///   themeMode: ThemeMode.system,
/// )
/// ```
///
/// ⚠️ 위젯에서 [AppColors]의 라이트/다크 전용 색을 직접 참조하지 말 것.
/// 다크 모드에서 그대로 남아 글자가 안 보인다. `Theme.of(context)` 를 경유한다.
/// 상태색(success·info·warning·error)만 두 모드 공통이라 직접 써도 된다.
library;

export 'app_colors.dart';
export 'app_dimens.dart';
export 'app_theme.dart';
