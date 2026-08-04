// 관리 콘솔 · 모델 버전
import { useQuery } from '@tanstack/react-query';

import { getActiveModelVersions } from '@/api';
import { qk } from '@/api/keys';
import { ListCount } from '@/components/ListCount';
import { Failed, Pending } from '@/components/QueryState';
import { formatDate } from '@/lib/format';
import { cn } from '@/lib/utils';

const GRID =
    'grid min-w-[32rem] grid-cols-[minmax(9rem,1.6fr)_4rem_7rem_6rem] items-center gap-x-5';

export default function AdminModelsPage() {
    const { data, isPending, isError, error, refetch } = useQuery({
        queryKey: qk.modelVersions,
        queryFn: getActiveModelVersions,
    });

    if (isPending) return <Pending />;
    if (isError) return <Failed error={error} onRetry={() => void refetch()} />;

    return (
        <div>
            <ListCount prefix="활성" value={data.length} unit="개" />

            <div
                className={cn(
                    GRID,
                    'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted',
                )}
            >
                <span>이름</span>
                <span>버전</span>
                <span className="text-right" title="예측 구간의 폭. 작을수록 구간이 좁습니다">
                    conformal_q
                </span>
                <span className="text-right">등록</span>
            </div>

            {data.length === 0 ? (
                <div className="py-16 text-center text-sm text-ink-faint">
                    활성 모델이 없습니다
                </div>
            ) : (
                <div className="divide-y divide-border">
                    {data.map((model) => (
                        <div key={model.id} className={cn(GRID, 'py-3.5')}>
                            <span className="truncate font-mono text-sm" title={model.name}>
                                {model.name}
                            </span>

                            <span className="font-mono text-sm text-ink-muted">
                                {model.version}
                            </span>

                            <span className="text-right font-mono text-sm tabular-nums">
                                {model.conformal_q.toFixed(3)}
                            </span>

                            <span className="truncate text-right text-sm text-ink-muted">
                                {formatDate(model.created_at)}
                            </span>
                        </div>
                    ))}
                </div>
            )}

            <p className="mt-4 text-xs text-ink-faint">
                활성 상태인 모델만 표시됩니다
            </p>
        </div>
    );
}
