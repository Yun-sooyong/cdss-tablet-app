import { useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { toast } from 'sonner';

import { getBatches, getJobsByBatch } from '@/api';
import { needsReview } from '@/lib/decision';
import { isBatchTerminal } from '@/lib/jobStatus';
import { patientBrief } from '@/lib/patient';

const POLL_MS = 5000;

// 어느 화면에 있든 완료를 알리려면 폴링이 셸 안에 있어야 한다.
// 07 안에서만 돌리면 그 화면을 떠난 순간 아무도 배치를 보지 않는다.
export function AnalysisWatcher() {
    const navigate = useNavigate();
    const watching = useRef<Set<string>>(new Set());
    const started = useRef(false);

    useEffect(() => {
        function tick() {
            for (const batch of getBatches()) {
                const terminal = isBatchTerminal(batch.status);

                if (!terminal) {
                    watching.current.add(batch.id);
                    continue;
                }

                // 진행 중이던 것이 종료로 바뀐 순간에만 알린다
                if (!watching.current.delete(batch.id)) continue;
                if (!started.current) continue;

                const jobs = getJobsByBatch(batch.id);
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

            // 첫 순회는 현재 상태를 기록만 한다. 앱을 켜자마자 옛 배치로 토스트가 쏟아지면 안 된다
            started.current = true;
        }

        tick();
        const id = setInterval(tick, POLL_MS);
        return () => clearInterval(id);
    }, [navigate]);

    return null;
}