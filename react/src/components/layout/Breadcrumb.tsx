import { Fragment } from 'react';
import { Link, matchPath, useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { ChevronRight } from 'lucide-react';

import { getBatchDetail, getJob } from '@/api';
import { qk } from '@/api/keys';
import { APP_NAME } from '@/lib/app';
import { patientLabel } from '@/lib/patient';
import { ADMIN_NAV_GROUPS, NAV_GROUPS } from './nav';

interface Crumb {
    label : string;
    // to 없음 >> 현재 위치
    to? : string;
}

const NAV_ITEMS = [...NAV_GROUPS, ...ADMIN_NAV_GROUPS].flatMap((group) => group.items);

// 사이드바에 없는 경로의 제목
const OFF_NAV_LABEL : Record<string, string> = {
    '/notifications': '알림',
    '/admin/notifications': '알림',
};

const CASES : Crumb = { label: '판독 목록', to: '/cases' };

export default function Breadcrumb() {
    const { pathname } = useLocation();

    const batchMatch = matchPath('/batches/:batchId', pathname);
    const resultMatch = matchPath('/results/:jobId', pathname);

    const jobId = resultMatch?.params.jobId;
    const { data: job } = useQuery({
        queryKey: qk.job(jobId ?? ''),
        queryFn: () => getJob(jobId!),
        enabled: !!jobId,
    });

    // 결과 상세에서는 job이 가리키는 배치를 따라간다
    const batchId = batchMatch?.params.batchId ?? job?.image_summary?.batch;
    const { data: batch } = useQuery({
        queryKey: qk.batch(batchId ?? ''),
        queryFn: () => getBatchDetail(batchId!),
        enabled: !!batchId,
    });

    // 아직 안 온 것은 식별자
    const batchCrumb = (id : string) : Crumb => {
        const who = batch ? patientLabel(batch.patient_summary) : null;

        return {
            label: who ? `${who} · ${id.slice(0, 8)}` : id.slice(0, 8),
            to: `/batches/${id}`,
        };
    };

    const crumbs : Crumb[] = (() => {
        if (batchMatch?.params.batchId) {
            return [CASES, batchCrumb(batchMatch.params.batchId)];
        }

        if (jobId) {
            const parent = job?.image_summary?.batch;
            const leaf = {
                label: job?.image_summary?.original_filename ?? jobId.slice(0, 8),
            };

            return parent ? [CASES, batchCrumb(parent), leaf] : [CASES, leaf];
        }

        const nav = NAV_ITEMS.find((item) => item.to === pathname);
        if (nav) return [{ label: nav.label }];

        const off = OFF_NAV_LABEL[pathname];
        return off ? [{ label: off }] : [];
    })();

    const ancestors = crumbs.slice(0, -1);
    const current = crumbs[crumbs.length - 1];

    return (
        <div className="mb-5 min-w-0">
            {ancestors.length > 0 && (
                <nav
                    aria-label="위치"
                    className="mb-1 flex min-w-0 items-center gap-1 text-xs text-ink-muted"
                >
                    {ancestors.map((crumb, at) => (
                        <Fragment key={crumb.to ?? crumb.label}>
                            {at > 0 && (
                                <ChevronRight size={12} className="shrink-0 text-ink-faint" />
                            )}

                            {crumb.to ? (
                                <Link
                                    to={crumb.to}
                                    className="shrink-0 transition-colors hover:text-ink"
                                >
                                    {crumb.label}
                                </Link>
                            ) : (
                                <span className="shrink-0">{crumb.label}</span>
                            )}
                        </Fragment>
                    ))}
                </nav>
            )}

            <h1 className="truncate text-lg font-bold tracking-tight text-ink">
                {current?.label ?? APP_NAME}
            </h1>
        </div>
    );
}
