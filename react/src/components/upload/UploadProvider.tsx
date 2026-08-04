import { useCallback, useEffect, useRef, useState } from 'react';
import type { ReactNode } from 'react';
import { useQueryClient } from '@tanstack/react-query';

import { startBatch, uploadToSignedUrl } from '@/api';
import { qk } from '@/api/keys';
import type { UploadContextValue, UploadItem } from './context';
import { UploadContext } from './context';

/* 백그라운드 업로드 큐 >> 헤더 인디케이터가 이 상태를 그린다 */

const CONCURRENCY = 3;

// 전부 끝난 뒤 완료 항목을 접기까지
const AUTO_CLEAR_MS = 4000;

interface BatchTicket {
    batchId : string;
    modelVersionId? : string;
    remaining : number;
}

export function UploadProvider({ children } : { children : ReactNode }) {
    const queryClient = useQueryClient();
    const [items, setItems] = useState<UploadItem[]>([]);
    const queue = useRef<UploadItem[]>([]);
    const running = useRef(0);
    const tickets = useRef<Map<string, BatchTicket>>(new Map());

    const patch = useCallback((id : string, next : Partial<UploadItem>) => {
        setItems((prev) => prev.map((it) => (it.id === id ? { ...it, ...next } : it)));
    }, []);

    const pump = useCallback(function pump() {
        while (running.current < CONCURRENCY && queue.current.length > 0) {
            const item = queue.current[0];
            queue.current = queue.current.slice(1);
            running.current += 1;
            patch(item.id, { status: 'uploading' });

            uploadToSignedUrl(item.uploadUrl, item.file, (percent) =>
                patch(item.id, { progress: percent }),
            )
                .then(() => {
                    patch(item.id, { status: 'done', progress: 100 });

                    // 배치의 파일이 전부 올라가면 분석 시작
                    const ticket = tickets.current.get(item.batchId);
                    if (!ticket) return;

                    const left = ticket.remaining - 1;
                    if (left > 0) {
                        tickets.current.set(item.batchId, { ...ticket, remaining: left });
                        return;
                    }

                    tickets.current.delete(item.batchId);

                    void startBatch(ticket.batchId, ticket.modelVersionId).then(() => {
                        void queryClient.invalidateQueries({ queryKey: qk.batches });
                        void queryClient.invalidateQueries({
                            queryKey: qk.batch(ticket.batchId),
                        });
                        void queryClient.invalidateQueries({ queryKey: qk.latestJobs });
                    });
                })
                .catch(() => patch(item.id, { status: 'failed' }))
                .finally(() => {
                    running.current -= 1;
                    pump();
                });
        }
    }, [patch, queryClient]);

    const enqueue = useCallback<UploadContextValue['enqueue']>(
        (batchId, modelVersionId, files) => {
            const next : UploadItem[] = files.map((f) => ({
                id: crypto.randomUUID(),
                batchId,
                filename: f.filename,
                uploadUrl: f.uploadUrl,
                file: f.file,
                progress: 0,
                status: 'waiting',
            }));

            tickets.current.set(batchId, {
                batchId,
                modelVersionId,
                remaining: next.length,
            });

            setItems((prev) => [...prev, ...next]);
            queue.current = [...queue.current, ...next];
            pump();
        },
        [pump],
    );

    const retry = useCallback(
        (id : string) => {
            setItems((prev) => {
                const target = prev.find((it) => it.id === id);
                if (target) {
                    queue.current = [
                        ...queue.current,
                        { ...target, progress: 0, status: 'waiting' },
                    ];
                }
                return prev.map((it) =>
                    it.id === id ? { ...it, progress: 0, status: 'waiting' } : it,
                );
            });
            pump();
        },
        [pump],
    );

    const clearFinished = useCallback(() => {
        setItems((prev) => prev.filter((it) => it.status !== 'done'));
    }, []);

    // 완료 항목 자동 정리 >> 실패만 남는다
    useEffect(() => {
        const busy = items.some(
            (it) => it.status === 'waiting' || it.status === 'uploading',
        );
        if (busy || !items.some((it) => it.status === 'done')) return;

        const id = setTimeout(
            () => setItems((prev) => prev.filter((it) => it.status !== 'done')),
            AUTO_CLEAR_MS,
        );

        return () => clearTimeout(id);
    }, [items]);

    return (
        <UploadContext.Provider value={{ items, enqueue, retry, clearFinished }}>
            {children}
        </UploadContext.Provider>
    );
}