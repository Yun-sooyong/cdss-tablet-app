import { useCallback, useRef, useState } from 'react';
import type { ReactNode } from 'react';

import { startBatch, uploadToSignedUrl } from '@/api';
import type { UploadContextValue, UploadItem } from './context';
import { UploadContext } from './context';

// 동시 3~4개가 적당하다. HTTP/1.1은 호스트당 연결이 6개라 그 이상 열면 대기만 늘고,
// 병리 이미지가 크면 대역폭도 나눠 쓴다.
const CONCURRENCY = 3;

interface BatchTicket {
    batchId : string;
    modelVersionId? : string;
    remaining : number;
}

export function UploadProvider({ children } : { children : ReactNode }) {
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

                    // 배치의 파일이 전부 올라가면 분석을 자동으로 시작한다
                    const ticket = tickets.current.get(item.batchId);
                    if (!ticket) return;

                    const left = ticket.remaining - 1;
                    if (left > 0) {
                        tickets.current.set(item.batchId, { ...ticket, remaining: left });
                        return;
                    }

                    startBatch(ticket.batchId, ticket.modelVersionId);
                    tickets.current.delete(item.batchId);
                })
                .catch(() => patch(item.id, { status: 'failed' }))
                .finally(() => {
                    running.current -= 1;
                    pump();
                });
        }
    }, [patch]);

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

    return (
        <UploadContext.Provider value={{ items, enqueue, retry, clearFinished }}>
            {children}
        </UploadContext.Provider>
    );
}