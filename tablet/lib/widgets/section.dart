import 'package:flutter/material.dart';
import 'package:shared/theme/theme.dart';

/// 작은 라벨 + 그 아래 카드. 모바일 디자인의 '오늘 복용' / '다음 예약' 패턴이다.
///
/// 카드 안에 제목을 넣지 않고 밖에 두면 카드가 내용만 담아 가벼워진다.
class Section extends StatelessWidget {
  const Section({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// 라벨 오른쪽에 놓을 액션 (더보기, 새로고침 등)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 2,
            bottom: AppDimens.gapSm,
          ),
          child: Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// 테두리만 있는 플랫 패널. Card를 쓰기 애매한 자리(고정 높이 컨테이너 등)에 쓴다.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimens.cardPadding),
    this.tinted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// 강조가 필요한 패널 (모바일의 '다음 예약' 카드처럼)
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: tinted
            ? theme.colorScheme.primary.withValues(alpha: 0.08)
            : theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: child,
    );
  }
}

/// 상태 태그. 작고 연한 pill — 목록의 주인공이 아니다.
class StatusTag extends StatelessWidget {
  const StatusTag(this.label, {super.key, this.tone = StatusTone.neutral});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final (bg, fg) = switch (tone) {
      StatusTone.positive => (
        cs.primary.withValues(alpha: 0.14),
        cs.primary,
      ),
      StatusTone.warning => (
        AppColors.warning.withValues(alpha: 0.16),
        AppColors.warning,
      ),
      StatusTone.danger => (cs.error.withValues(alpha: 0.12), cs.error),
      StatusTone.neutral => (cs.surfaceContainer, cs.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum StatusTone { neutral, positive, warning, danger }
