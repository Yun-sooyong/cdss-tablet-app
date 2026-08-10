import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Share2 } from 'lucide-react';
import { toast } from 'sonner';

import { createShare, getBatchDetail, getMe, getStaff } from '@/api';
import { qk } from '@/api/keys';
import { BUTTON_PRIMARY, BUTTON_QUIET, FIELD_INPUT } from '@/components/form';
import {
    Sheet,
    SheetContent,
    SheetHeader,
    SheetTitle,
} from '@/components/ui/sheet';
import { patientLabelFull } from '@/lib/patient';
import { staffBrief } from '@/lib/staff';
import { cn } from '@/lib/utils';

// 서버가 opinion을 200자로 자른다
const OPINION_MAX = 200;

// days 0 >> 만료 없음
const EXPIRY_OPTIONS = [
    { days: 0, label: '만료 없음' },
    { days: 7, label: '7일' },
    { days: 30, label: '30일' },
];

const expiresAt = (days : number) : string | null => {
    if (!days) return null;

    const at = new Date();
    at.setDate(at.getDate() + days);
    return at.toISOString();
};

/* 보고 있는 케이스를 그 자리에서 공유한다. 공유 페이지에서 다시 찾지 않는다 */
export function ShareSheet({ batchId } : { batchId : string }) {
    const queryClient = useQueryClient();
    const [open, setOpen] = useState(false);

    const { data: me } = useQuery({ queryKey: qk.me, queryFn: getMe });
    const { data: staff } = useQuery({ queryKey: qk.staff, queryFn: getStaff });
    const { data: batch } = useQuery({
        queryKey: qk.batch(batchId),
        queryFn: () => getBatchDetail(batchId),
    });

    const [targetId, setTargetId] = useState('');
    const [opinion, setOpinion] = useState('');
    const [days, setDays] = useState(0);

    const staffById = new Map((staff ?? []).map((s) => [s.id, s]));
    const targets = (staff ?? []).filter((s) => s.id !== me?.id);

    const send = useMutation({
        mutationFn: () =>
            createShare(batchId, {
                shared_to: targetId,
                opinion: opinion.trim(),
                expires_at: expiresAt(days),
            }),
        onSuccess: (share) => {
            void queryClient.invalidateQueries({ queryKey: qk.sharesOut });
            setTargetId('');
            setOpinion('');
            setOpen(false);
            toast.success('공유했습니다', {
                description: staffById.get(share.shared_to)?.username ?? share.shared_to,
            });
        },
        onError: (err : Error) =>
            toast.error('공유하지 못했습니다', { description: err.message }),
    });

    // 소유자만 공유할 수 있다. 남의 케이스에는 버튼 자체를 띄우지 않는다
    if (!batch || !me || batch.created_by !== me.id) return null;

    // 담당의는 LOW/HIGH만 받는다. 확정이 남아 있으면 아직 못 보낸다
    const ready = batch.status === 'done' && batch.needs_review_count === 0;

    return (
        <>
            <button
                type="button"
                onClick={() => setOpen(true)}
                disabled={!ready}
                title={ready ? undefined : '판정이 끝나지 않아 공유할 수 없습니다'}
                className={cn(BUTTON_QUIET, 'h-8 px-2.5 text-sm')}
            >
                <Share2 size={14} />
                공유
            </button>

            <Sheet open={open} onOpenChange={setOpen}>
                <SheetContent className="w-full overflow-y-auto sm:max-w-md">
                    <SheetHeader>
                        <SheetTitle className="text-base">공유</SheetTitle>
                        <p className="truncate text-sm text-ink-faint">
                            {patientLabelFull(batch.patient_summary)}
                        </p>
                    </SheetHeader>

                    <div className="space-y-4 px-4 pb-6">
                        <label className="block">
                            <span className="mb-1.5 block text-xs text-ink-muted">
                                받는 사람
                            </span>
                            <select
                                value={targetId}
                                onChange={(e) => setTargetId(e.target.value)}
                                className={FIELD_INPUT}
                            >
                                <option value="">선택하세요</option>
                                {targets.map((s) => (
                                    <option key={s.id} value={s.id}>
                                        {staffBrief(s)}
                                    </option>
                                ))}
                            </select>
                        </label>

                        <label className="block">
                            <span className="mb-1.5 flex items-baseline justify-between text-xs text-ink-muted">
                                <span>의견 (선택)</span>
                                <span
                                    className={cn(
                                        'font-mono tabular-nums',
                                        opinion.length === OPINION_MAX && 'text-danger',
                                    )}
                                >
                                    {opinion.length}/{OPINION_MAX}
                                </span>
                            </span>
                            <textarea
                                value={opinion}
                                onChange={(e) => setOpinion(e.target.value)}
                                maxLength={OPINION_MAX}
                                rows={4}
                                placeholder="받는 사람이 함께 볼 메모를 남길 수 있습니다"
                                className={`${FIELD_INPUT} h-auto resize-y py-2 leading-relaxed`}
                            />
                        </label>

                        <label className="block">
                            <span className="mb-1.5 block text-xs text-ink-muted">
                                유효기간
                            </span>
                            <select
                                value={days}
                                onChange={(e) => setDays(Number(e.target.value))}
                                className={FIELD_INPUT}
                            >
                                {EXPIRY_OPTIONS.map((o) => (
                                    <option key={o.days} value={o.days}>
                                        {o.label}
                                    </option>
                                ))}
                            </select>
                        </label>

                        <button
                            type="button"
                            onClick={() => send.mutate()}
                            disabled={!targetId || send.isPending}
                            className={`w-full ${BUTTON_PRIMARY}`}
                        >
                            공유
                        </button>
                    </div>
                </SheetContent>
            </Sheet>
        </>
    );
}
