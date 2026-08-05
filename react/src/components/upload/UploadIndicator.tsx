import { Check, CloudUpload, RotateCcw } from 'lucide-react';

import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';
import { stalledBatchIds, useUploads } from './context';

export function UploadIndicator({ collapsed } : { collapsed? : boolean }) {
    const { items, retry, clearFinished } = useUploads();

    const active = items.filter((it) => it.status !== 'done');
    if (items.length === 0) return null;

    const done = items.length - active.length;
    const overall = Math.round(
        items.reduce((sum, it) => sum + it.progress, 0) / items.length,
    );
    const failed = items.some((it) => it.status === 'failed');
    const stalled = stalledBatchIds(items).size;

    return (
        <Popover>
            {/* 진행·실패를 화면에 안 띄워도 읽어 줘야 한다 */}
            <PopoverTrigger
                aria-live="polite"
                aria-label={`업로드 ${done}/${items.length}`}
                title={collapsed ? `업로드 ${done}/${items.length} · ${overall}%` : undefined}
                className={cn(
                    'flex h-8 items-center rounded-md text-sm text-ink-muted transition-colors hover:bg-ink/[0.04] hover:text-ink',
                    collapsed ? 'w-full justify-center' : 'w-full gap-2.5 px-2.5',
                )}
            >
                <span className="relative flex shrink-0 items-center">
                    <CloudUpload size={16} className={cn(failed && 'text-danger')} />
                    {collapsed && (failed || stalled > 0) && (
                        <span className="absolute -right-0.5 -top-0.5 size-1.5 rounded-full bg-danger" />
                    )}
                </span>

                {!collapsed && (
                    <>
                        <span className="flex-1 text-left">업로드 {done}/{items.length}</span>
                        <span className="font-mono text-xs tabular-nums">{overall}%</span>
                    </>
                )}
            </PopoverTrigger>

            <PopoverContent side="right" align="end" className="w-96 p-0">
                <div className="flex items-center justify-between border-b border-border px-4 py-3">
                    <span className="text-sm font-medium">업로드</span>
                    {done > 0 && (
                        <button
                            type="button"
                            onClick={clearFinished}
                            className="text-xs text-ink-muted transition-colors hover:text-ink"
                        >
                            완료 항목 지우기
                        </button>
                    )}
                </div>

                <div className="max-h-80 divide-y divide-border overflow-y-auto">
                    {items.map((it) => (
                        <div key={it.id} className="px-4 py-3">
                            <div className="flex items-center gap-2">
                                <span className="min-w-0 flex-1 truncate text-sm" title={it.filename}>
                                    {it.filename}
                                </span>

                                {it.status === 'failed' ? (
                                    <button
                                        type="button"
                                        onClick={() => retry(it.id)}
                                        className="flex items-center gap-1 text-xs text-danger"
                                    >
                                        <RotateCcw size={12} />
                                        재시도
                                    </button>
                                ) : it.status === 'done' ? (
                                    <Check size={14} className="text-brand" />
                                ) : (
                                    <span className="font-mono text-xs tabular-nums text-ink-muted">
                                        {Math.round(it.progress)}%
                                    </span>
                                )}
                            </div>

                            <div className="mt-2 h-1 overflow-hidden rounded-full bg-border">
                                <div
                                    className={cn(
                                        'h-full rounded-full transition-[width]',
                                        it.status === 'failed'
                                            ? 'bg-danger'
                                            : it.status === 'done'
                                              ? 'bg-brand/40'
                                              : 'bg-brand',
                                    )}
                                    style={{ width: `${it.progress}%` }}
                                />
                            </div>
                        </div>
                    ))}
                </div>

                {stalled > 0 && (
                    <p
                        role="alert"
                        className="border-t border-border px-4 py-2.5 text-xs text-danger"
                    >
                        재시도하기 전까지 분석이 시작되지 않습니다
                    </p>
                )}

                <p className="border-t border-border px-4 py-2.5 text-xs text-ink-faint">
                    창을 닫으면 업로드가 중단됩니다
                </p>
            </PopoverContent>
        </Popover>
    );
}
