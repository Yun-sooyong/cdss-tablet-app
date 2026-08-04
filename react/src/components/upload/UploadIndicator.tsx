import { CloudUpload, RotateCcw } from 'lucide-react';

import { Popover, PopoverContent, PopoverTrigger } from '@/components/ui/popover';
import { cn } from '@/lib/utils';
import { useUploads } from './context';

export function UploadIndicator() {
    const { items, retry, clearFinished } = useUploads();

    const active = items.filter((it) => it.status !== 'done');
    if (items.length === 0) return null;

    const done = items.length - active.length;
    const overall = Math.round(
        items.reduce((sum, it) => sum + it.progress, 0) / items.length,
    );
    const failed = items.some((it) => it.status === 'failed');

    return (
        <Popover>
            {/* 진행·실패를 화면에 안 띄워도 읽어 줘야 한다 */}
            <PopoverTrigger
                aria-live="polite"
                className="flex items-center gap-2 rounded-md border border-border px-3 py-1.5 text-sm text-ink-muted transition-colors hover:text-ink"
            >
                <CloudUpload size={15} className={cn(failed && 'text-danger')} />
                업로드 {done}/{items.length}
                <span className="font-mono tabular-nums">{overall}%</span>
            </PopoverTrigger>

            <PopoverContent align="end" className="w-96 p-0">
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
                                        it.status === 'failed' ? 'bg-danger' : 'bg-brand',
                                    )}
                                    style={{ width: `${it.progress}%` }}
                                />
                            </div>
                        </div>
                    ))}
                </div>

                <p className="border-t border-border px-4 py-2.5 text-xs text-ink-faint">
                    창을 닫으면 업로드가 중단됩니다
                </p>
            </PopoverContent>
        </Popover>
    );
}