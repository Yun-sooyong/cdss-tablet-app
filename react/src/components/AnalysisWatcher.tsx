import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';

import { getBatches, getJobsByBatch } from '@/api';
import { qk } from '@/api/keys';
import { needsReview } from '@/lib/decision';
import { isBatchTerminal } from '@/lib/jobStatus';
import { patientBrief } from '@/lib/patient';

const POLL_MS = 5000;

/* 분석 완료 감시 >> 화면과 무관하게 세션 내내 돈다. 완료 시 토스트 */
export function AnalysisWatcher() {
    const navigate = useNavigate();
    const queryClient = useQueryClient();

    const watching = useRef<Set<string>>(new Set());
    const started = useRef(false);

    useEffect(() => {
        let alive = true;

        async function tick() {
            const batches = await getBatches().catch(() => null);
            if (!alive || !batches) return;

            for (const batch of batches) {
                if (!isBatchTerminal(batch.status)) {
                    watching.current.add(batch.id);
                    continue;
                }

                // 진행 중 → 종료로 바뀐 것만
                if (!watching.current.delete(batch.id)) continue;
                if (!started.current) continue;

                void queryClient.invalidateQueries({ queryKey: qk.batches });
                void queryClient.invalidateQueries({ queryKey: qk.latestJobs });

                const jobs = await getJobsByBatch(batch.id).catch(() => []);
                if (!alive) return;

                const review = jobs.filter((j) => needsReview(j.result)).length;
                const who = batch.patient_summary
                    ? patientBrief(batch.patient_summary)
                    : '환자 미연결';

                toast(batch.status === 'failed' ? '분석 실패' : '분석 완료', {
                    description:
                        review > 0
                            ? `${who} · ${jobs.length}건 중 확인 필요 ${review}건`
                            : `${who} · ${jobs.length}건`,
                    action: {
                        label: '보기',
                        onClick: () => navigate(`/batches/${batch.id}`),
                    },
                });
            }

            // 첫 순회는 기록만
            started.current = true;
        }

        void tick();
        const id = setInterval(() => void tick(), POLL_MS);

        return () => {
            alive = false;
            clearInterval(id);
        };
    }, [navigate, queryClient]);

    return null;
}
