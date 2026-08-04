import { useState } from 'react';
import { Maximize2, Minus, Plus } from 'lucide-react';
import { TransformComponent, TransformWrapper } from 'react-zoom-pan-pinch';

import { PlaceholderMask, PlaceholderSlide } from '@/dev';
import { cn } from '@/lib/utils';

const SEG_LEGEND = [
    { label: '종양', className: 'bg-seg-tumor' },
    { label: '기질', className: 'bg-seg-stroma' },
    { label: '림프구', className: 'bg-seg-tils' },
];

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
                {({ zoomIn, zoomOut, resetTransform }) => (
                    <>
                        <div className="relative bg-viewer">
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
                                            <PlaceholderMask className="h-full w-full" />
                                        )}
                                    </div>
                                </div>
                            </TransformComponent>

                            <div className="absolute right-3 top-3 flex flex-col gap-1">
                                <ViewerButton onClick={() => zoomIn()} label="확대">
                                    <Plus size={15} />
                                </ViewerButton>
                                <ViewerButton onClick={() => zoomOut()} label="축소">
                                    <Minus size={15} />
                                </ViewerButton>
                                <ViewerButton onClick={() => resetTransform()} label="원래대로">
                                    <Maximize2 size={15} />
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
                                {SEG_LEGEND.map((s) => (
                                    <span
                                        key={s.label}
                                        className="flex items-center gap-1.5 text-xs text-viewer-ink"
                                    >
                                        <span className={cn('size-2.5 rounded-sm', s.className)} />
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
