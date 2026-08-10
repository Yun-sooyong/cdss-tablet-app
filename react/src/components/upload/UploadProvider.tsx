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
    total : number;
    done : number;
    failed : number;
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

    // settle
    const settle = useCallback((batchId : string, ok : boolean) => {
        const ticket = tickets.current.get(batchId);
        if (!ticket) return;

        const next = ok
            ? { ...ticket, done: ticket.done + 1 }
            : { ...ticket, failed: ticket.failed + 1 };

        tickets.current.set(batchId, next);

        if (next.done + next.failed < next.total) return;
        if (next.failed > 0) return;

        tickets.current.delete(batchId);

        void startBatch(batchId, next.modelVersionId).then(() => {
            void queryClient.invalidateQueries({ queryKey: qk.batches });
            void queryClient.invalidateQueries({ queryKey: qk.batch(batchId) });
            void queryClient.invalidateQueries({ queryKey: qk.latestJobs });
        });
    }, [queryClient]);

    const pump = useCallback(function pump() {
        while (running.current < CONCURRENCY && queue.current.length > 0) {
            const item = queue.current[0];
            queue.current = queue.current.slice(1);
            running.current += 1;
            patch(item.id, { status: 'uploading' });

            uploadToSignedUrl(item.uploadUrl, item.file, item.contentType, (percent) =>
                patch(item.id, { progress: percent }),
            )
                .then(() => {
                    patch(item.id, { status: 'done', progress: 100 });
                    settle(item.batchId, true);
                })
                .catch(() => {
                    patch(item.id, { status: 'failed' });
                    settle(item.batchId, false);
                })
                .finally(() => {
                    running.current -= 1;
                    pump();
                });
        }
    }, [patch, settle]);

    const enqueue = useCallback<UploadContextValue['enqueue']>(
        (batchId, modelVersionId, files) => {
            const next : UploadItem[] = files.map((f) => ({
                id: crypto.randomUUID(),
                batchId,
                filename: f.filename,
                uploadUrl: f.uploadUrl,
                contentType: f.contentType,
                file: f.file,
                progress: 0,
                status: 'waiting',
            }));

            tickets.current.set(batchId, {
                batchId,
                modelVersionId,
                total: next.length,
                done: 0,
                failed: 0,
            });

            setItems((prev) => [...prev, ...next]);
            queue.current = [...queue.current, ...next];
            pump();
        },
        [pump],
    );

    const retry = useCallback(
        (id : string) => {
            const target = items.find((it) => it.id === id);
            if (!target || target.status !== 'failed') return;

            const ticket = tickets.current.get(target.batchId);
            if (ticket) {
                tickets.current.set(target.batchId, {
                    ...ticket,
                    failed: Math.max(0, ticket.failed - 1),
                });
            }

            queue.current = [
                ...queue.current,
                { ...target, progress: 0, status: 'waiting' },
            ];
            patch(id, { progress: 0, status: 'waiting' });
            pump();
        },
        [items, patch, pump],
    );

    const clearFinished = useCallback(() => {
        setItems((prev) => prev.filter((it) => it.status !== 'done'));
    }, []);

    // beforeunload
    useEffect(() => {
        if (!items.some((it) => it.status !== 'done')) return;

        const warn = (e : BeforeUnloadEvent) => e.preventDefault();
        window.addEventListener('beforeunload', warn);

        return () => window.removeEventListener('beforeunload', warn);
    }, [items]);

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