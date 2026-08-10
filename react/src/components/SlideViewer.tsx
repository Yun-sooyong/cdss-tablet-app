import { useState } from 'react';
import { Minus, Plus, RotateCcw } from 'lucide-react';
import { TransformComponent, TransformWrapper } from 'react-zoom-pan-pinch';

import { PlaceholderBadge, PlaceholderMask, PlaceholderSlide } from '@/dev';
import { SEG_CLASSES } from '@/lib/seg';
import { cn } from '@/lib/utils';

// PAN_STEP
const PAN_STEP : Record<string, [number, number]> = {
    ArrowLeft: [40, 0],
    ArrowRight: [-40, 0],
    ArrowUp: [0, 40],
    ArrowDown: [0, -40],
};

export function SlideViewer({
    originalUrl,
    maskUrl,
    className,
}: {
    originalUrl?: string;
    maskUrl?: string;
    className?: string;
}) {
    const [opacity, setOpacity] = useState(55);

    return (
        <div className={cn('overflow-hidden rounded-lg border border-viewer-border', className)}>
            <TransformWrapper doubleClick={{ mode: 'reset' }} minScale={1} maxScale={8}>
                {({ zoomIn, zoomOut, resetTransform, instance, setTransform }) => (
                    <>
                        <div
                            role="group"
                            aria-label="슬라이드 뷰어. 방향키로 이동합니다"
                            tabIndex={0}
                            onKeyDown={(e) => {
                                const step = PAN_STEP[e.key];
                                if (!step) return;

                                e.preventDefault();
                                const { positionX, positionY, scale } = instance.state;
                                setTransform(positionX + step[0], positionY + step[1], scale);
                            }}
                            className="relative bg-viewer"
                        >
                            <TransformComponent
                                wrapperClass="!w-full !h-[420px]"
                                contentClass="!w-full !h-full"
                            >
                                {/* 원본과 마스크가 같은 변환을 받아야 확대해도 정렬이 안 깨진다 */}
                                <div className="relative h-full w-full">
                                    {originalUrl ? (
                                        <img
                                            src={originalUrl}
                                            alt="원본 슬라이드"
                                            className="h-full w-full object-contain"
                                        />
                                    ) : (
                                        <PlaceholderSlide className="h-full w-full" />
                                    )}

                                    <div
                                        className="absolute inset-0"
                                        style={{ opacity: opacity / 100 }}
                                    >
                                        {maskUrl ? (
                                            <img
                                                src={maskUrl}
                                                alt="세그멘테이션 마스크"
                                                className="h-full w-full object-contain"
                                            />
                                        ) : (
                                            // 진짜 원본 위에 예시 마스크를 덮지 않는다
                                            !originalUrl && (
                                                <PlaceholderMask className="h-full w-full" />
                                            )
                                        )}
                                    </div>
                                </div>
                            </TransformComponent>

                            {!originalUrl && <PlaceholderBadge />}

                            <div className="absolute right-3 top-3 flex flex-col gap-1">
                                <ViewerButton onClick={() => zoomIn()} label="확대">
                                    <Plus size={15} />
                                </ViewerButton>
                                <ViewerButton onClick={() => zoomOut()} label="축소">
                                    <Minus size={15} />
                                </ViewerButton>
                                <ViewerButton onClick={() => resetTransform()} label="원래대로">
                                    <RotateCcw size={15} />
                                </ViewerButton>
                            </div>
                        </div>

                        <div className="flex items-center gap-4 border-t border-viewer-border bg-viewer-chrome px-4 py-3">
                            <label className="flex flex-1 items-center gap-3 text-xs text-viewer-ink">
                                마스크
                                <input
                                    type="range"
                                    min={0}
                                    max={100}
                                    value={opacity}
                                    onChange={(e) => setOpacity(Number(e.target.value))}
                                    className="flex-1 accent-[var(--seg-abstain)]"
                                />
                                <span className="w-9 text-right font-mono tabular-nums">
                                    {opacity}%
                                </span>
                            </label>

                            <div className="flex items-center gap-3">
                                {SEG_CLASSES.map((s) => (
                                    <span
                                        key={s.label}
                                        className="flex items-center gap-1.5 text-xs text-viewer-ink"
                                    >
                                        <span
                                            className="size-2.5 rounded-sm"
                                            style={{ backgroundColor: `var(${s.token})` }}
                                        />
                                        {s.label}
                                    </span>
                                ))}
                            </div>
                        </div>
                    </>
                )}
            </TransformWrapper>
        </div>
    );
}

function ViewerButton({
    onClick,
    label,
    children,
}: {
    onClick: () => void;
    label: string;
    children: React.ReactNode;
}) {
    return (
        <button
            type="button"
            onClick={onClick}
            aria-label={label}
            className="flex size-8 items-center justify-center rounded-md border border-viewer-border bg-viewer-chrome text-viewer-ink transition-opacity hover:opacity-80"
        >
            {children}
        </button>
    );
}
