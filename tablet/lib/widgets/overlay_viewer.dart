import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared/theme/theme.dart';
import 'package:tablet/models/models.dart';

/// 더블탭이 순환하는 배율. 1배로 돌아오면 위치도 초기화한다.
const _zoomSteps = [1.0, 2.0, 4.0];

/// 탭한 지점을 고정한 채 배율만 바꾼다.
///
/// 화면 중심 기준으로만 확대하면 보려던 조직이 화면 밖으로 밀려난다.
/// 탭 지점 아래의 이미지 좌표가 그대로 남도록 위치를 다시 계산한다.
void _zoomAt(
  PhotoViewController controller, {
  required Offset tap,
  required Offset center,
}) {
  final now = controller.scale ?? 1.0;
  // 현재 배율보다 큰 첫 단계로, 없으면 처음으로 돌아간다
  final next = _zoomSteps.firstWhere(
    (s) => s > now + 0.01,
    orElse: () => _zoomSteps.first,
  );

  if (next == _zoomSteps.first) {
    controller.position = Offset.zero;
    controller.scale = next;
    return;
  }

  final ratio = next / now;
  final p = controller.position;
  controller.position = (tap - center) * (1 - ratio) + p * ratio;
  controller.scale = next;
}

/// 원본 위에 세그멘테이션 마스크를 겹쳐 투명도로 비교하는 판독 뷰어.
///
/// 슬라이더 0 = 원본만, 1 = 마스크만. 그래서 별도 토글 버튼이 필요 없다.
class OverlayViewer extends HookWidget {
  const OverlayViewer({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final opacity = useState(0.5);

    // 확대 배율을 화면에 표시하고 리셋할 수 있게 컨트롤러를 직접 들고 있는다.
    // 판독 중에 배율을 잃어버리는 게 제일 답답하다.
    final controller = useMemoized(PhotoViewController.new);
    useEffect(() => controller.dispose, [controller]);
    final scale = useState(1.0);
    useEffect(() {
      final sub = controller.outputStateStream.listen((s) {
        if (s.scale != null) scale.value = s.scale!;
      });
      return sub.cancel;
    }, [controller]);
    // onDoubleTap에는 좌표가 없어서 onDoubleTapDown에서 받아둔다
    final tapPos = useRef(Offset.zero);

    final hasMask = job.maskUrl != null;
    final hasOriginal = job.originalUrl != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('세그멘테이션 오버레이', style: theme.textTheme.titleMedium),
            // 파일명이 50자를 넘는 경우가 있다(TCGA-...-MPP-0.2500.png).
            // Flexible 없이 두면 배율 배지·리셋 버튼을 밀어내며 오버플로가 난다.
            if (job.image != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.gapMd,
                  ),
                  child: Text(
                    job.image!.originalFilename,
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              const Spacer(),
            _ScaleBadge(scale: scale.value),
          ],
        ),
        const SizedBox(height: AppDimens.gapMd),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainer,
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(AppDimens.radius),
              ),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                // 에뮬레이터·데스크톱에는 핀치가 없다. 더블탭이 유일한 확대 수단이다.
                onDoubleTapDown: (d) => tapPos.value = d.localPosition,
                onDoubleTap: () => _zoomAt(
                  controller,
                  tap: tapPos.value,
                  center: constraints.biggest.center(Offset.zero),
                ),
                // 원본과 마스크를 겹친 채로 같이 확대해야 하므로 customChild를 쓴다.
                // 두 장이 한 Stack 안에 있어 배율·위치가 항상 함께 움직인다.
                child: PhotoView.customChild(
                  controller: controller,
                  // ⚠️ PhotoViewComputedScale은 customChild에 childSize를 주지 않으면
                  // 배율이 어긋나 확대가 아예 안 먹는다. 숫자로 고정한다.
                  minScale: 0.5,
                  maxScale: 8.0,
                  initialScale: 1.0,
                  backgroundDecoration: BoxDecoration(
                    color: cs.surfaceContainer,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                  // 아래: 원본
                  if (hasOriginal)
                    Image.network(
                      job.originalUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          _Notice(text: '원본을 불러오지 못했습니다', icon: Icons.broken_image_outlined),
                    )
                  else
                    const _Notice(
                      text: '원본 이미지는 서버가 조회 URL(original_url)을\n'
                          '제공하면 여기에 표시됩니다',
                      icon: Icons.image_not_supported_outlined,
                    ),

                  // 위: 마스크
                  if (hasMask)
                    Opacity(
                      opacity: opacity.value,
                      child: Image.network(
                        job.maskUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(child: CircularProgressIndicator()),
                        // 서명 URL은 15분이면 만료된다. 객체 자체가 없는 경우도 있다.
                        errorBuilder: (_, _, _) => const _Notice(
                          text: '마스크를 불러오지 못했습니다\n(서명 만료이거나 객체가 없습니다)',
                          icon: Icons.layers_clear_outlined,
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimens.gapMd),

        Row(
          children: [
            Text('원본', style: TextStyle(color: cs.onSurfaceVariant)),
            Expanded(
              child: Slider(
                value: opacity.value,
                onChanged: hasMask ? (v) => opacity.value = v : null,
              ),
            ),
            Text('마스크', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(width: AppDimens.gapMd),
            SizedBox(
              width: 48,
              child: Text(
                '${(opacity.value * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 현재 배율. 판독 중 어디까지 확대했는지 알 수 있어야 한다.
class _ScaleBadge extends StatelessWidget {
  const _ScaleBadge({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      ),
      child: Text(
        '${(scale * 100).round()}%',
        style: TextStyle(
          color: cs.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 이미지 한 장을 전체화면으로 열어 확대해 본다.
///
/// 대시보드 우측 패널의 작은 썸네일에서 바로 띄운다.
Future<void> showImageDialog(
  BuildContext context, {
  required String url,
  required String title,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (context) => _ImageDialog(url: url, title: title),
  );
}

class _ImageDialog extends HookWidget {
  const _ImageDialog({required this.url, required this.title});

  final String url;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = useMemoized(PhotoViewController.new);
    useEffect(() => controller.dispose, [controller]);
    final scale = useState(1.0);
    useEffect(() {
      final sub = controller.outputStateStream.listen((s) {
        if (s.scale != null) scale.value = s.scale!;
      });
      return sub.cancel;
    }, [controller]);
    final tapPos = useRef(Offset.zero);

    return Dialog(
      insetPadding: const EdgeInsets.all(AppDimens.gapXl),
      backgroundColor: theme.colorScheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.gapXl,
              AppDimens.gapLg,
              AppDimens.gapMd,
              AppDimens.gapSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                _ScaleBadge(scale: scale.value),
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                onDoubleTapDown: (d) => tapPos.value = d.localPosition,
                onDoubleTap: () => _zoomAt(
                  controller,
                  tap: tapPos.value,
                  center: constraints.biggest.center(Offset.zero),
                ),
                child: PhotoView(
                  controller: controller,
                  imageProvider: NetworkImage(url),
                  minScale: PhotoViewComputedScale.contained * 0.5,
                  maxScale: PhotoViewComputedScale.covered * 8,
                  initialScale: PhotoViewComputedScale.contained,
                  backgroundDecoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                  ),
                  loadingBuilder: (_, _) =>
                      const Center(child: CircularProgressIndicator()),
                  // 서명 URL은 15분이면 만료된다
                  errorBuilder: (_, _, _) => const _Notice(
                    text: '이미지를 불러오지 못했습니다\n(서명 만료이거나 객체가 없습니다)',
                    icon: Icons.broken_image_outlined,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimens.gapXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.disabledColor),
            const SizedBox(height: AppDimens.gapMd),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.disabledColor, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
