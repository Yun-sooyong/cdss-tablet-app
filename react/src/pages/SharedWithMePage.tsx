// 13 공유받은 항목
import { Link } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';

import { getBatches, getSharesToMe, getStaff } from '@/api';
import { qk } from '@/api/keys';
import type { AnalysisShare, Batch, Staff } from '@/api/types';
import { ListCount } from '@/components/ListCount';
import { Failed, Pending } from '@/components/QueryState';
import { StateBadge } from '@/components/StateBadge';
import { formatShort } from '@/lib/format';
import { patientBrief } from '@/lib/patient';
import { PERMISSION_LABEL, SHARE_STATE_LABEL, shareState } from '@/lib/share';
import { staffBrief } from '@/lib/staff';
import { cn } from '@/lib/utils';

const GRID =
    'grid grid-cols-[minmax(9rem,1.6fr)_minmax(7rem,1fr)_4rem_5rem_6rem] items-center gap-x-5';

export default function SharedWithMePage() {
    const shares = useQuery({ queryKey: qk.sharesIn, queryFn: getSharesToMe });

    // 보낸 사람 >> shared_by는 id뿐이라 목록으로 짝지운다
    const { data: staff } = useQuery({ queryKey: qk.staff, queryFn: getStaff });

    // 공유받은 배치는 배치 목록에 함께 온다
    const { data: batches } = useQuery({ queryKey: qk.batches, queryFn: getBatches });

    if (shares.isPending) return <Pending />;
    if (shares.isError) {
        return <Failed error={shares.error} onRetry={() => void shares.refetch()} />;
    }

    const staffById = new Map<string, Staff>((staff ?? []).map((s) => [s.id, s]));
    const batchById = new Map<string, Batch>((batches ?? []).map((b) => [b.id, b]));

    return (
        <div>
            <ListCount value={shares.data.length} unit="건" />

            <div
                className={cn(
                    GRID,
                    'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted',
                )}
            >
                <span>케이스</span>
                <span>보낸 사람</span>
                <span>권한</span>
                <span>상태</span>
                <span className="text-right">받은 시각</span>
            </div>

            {shares.data.length === 0 ? (
                <div className="py-16 text-center text-sm text-ink-faint">
                    공유받은 항목이 없습니다
                </div>
            ) : (
                <div className="divide-y divide-border">
                    {shares.data.map((share) => (
                        <ShareRow
                            key={share.id}
                            share={share}
                            sender={staffById.get(share.shared_by)}
                            batch={batchById.get(share.batch)}
                        />
                    ))}
                </div>
            )}
        </div>
    );
}

function ShareRow({
    share,
    sender,
    batch,
} : {
    share : AnalysisShare;
    sender? : Staff;
    batch? : Batch;
}) {
    const state = shareState(share);

    const label = batch?.patient_summary
        ? patientBrief(batch.patient_summary)
        : batch
          ? '환자 미연결'
          : '—';

    const body = (
        <>
            <span className="min-w-0">
                <span className="block truncate text-[15px]">{label}</span>
                <span className="block truncate font-mono text-[13px] text-ink-faint">
                    {share.batch.slice(0, 8)}
                </span>
            </span>

            <span className="truncate text-sm text-ink-muted">
                {sender ? staffBrief(sender) : '알 수 없음'}
            </span>

            <span className="text-sm text-ink-muted">
                {PERMISSION_LABEL[share.permission]}
            </span>

            <span>
                <StateBadge label={SHARE_STATE_LABEL[state]} live={state === 'live'} />
            </span>

            <span className="text-right text-sm text-ink-muted">
                {formatShort(share.created_at)}
            </span>
        </>
    );

    // 만료·회수 >> 링크 없음
    if (state !== 'live') {
        return (
            <div className={cn(GRID, 'py-4 opacity-60')} title={SHARE_STATE_LABEL[state]}>
                {body}
            </div>
        );
    }

    return (
        <Link
            to={`/batches/${share.batch}`}
            className={cn(GRID, 'py-4 transition-colors hover:bg-brand-soft/50')}
        >
            {body}
        </Link>
    );
}
