import { Fragment } from 'react';
import { Link, matchPath, useLocation } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { ChevronRight } from 'lucide-react';

import { getBatchDetail, getImage, getJob } from '@/api';
import { qk } from '@/api/keys';
import { patientBrief } from '@/lib/patient';
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

    // Job에 batch 필드가 없어 image를 거쳐야 배치를 알 수 있다
    const imageId = job?.image;
    const { data: image } = useQuery({
        queryKey: qk.image(imageId ?? ''),
        queryFn: () => getImage(imageId!),
        enabled: !!imageId,
    });

    const batchId = batchMatch?.params.batchId ?? image?.batch;
    const { data: batch } = useQuery({
        queryKey: qk.batch(batchId ?? ''),
        queryFn: () => getBatchDetail(batchId!),
        enabled: !!batchId,
    });

    // 아직 안 온 것은 식별자로 버틴다. 제목이 빈 채로 깜빡이지 않게
    const batchCrumb = (id : string) : Crumb => {
        const who = batch?.patient_summary
            ? patientBrief(batch.patient_summary)
            : batch
              ? '환자 미연결'
              : null;

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
            return [
                CASES,
                ...(image ? [batchCrumb(image.batch)] : []),
                { label: image?.original_filename ?? jobId.slice(0, 8) },
            ];
        }

        const nav = NAV_ITEMS.find((item) => item.to === pathname);
        if (nav) return [{ label: nav.label }];

        const off = OFF_NAV_LABEL[pathname];
        return off ? [{ label: off }] : [];
    })();

    return (
        <nav
            aria-label="위치"
            className="flex min-w-0 items-center gap-1.5 text-[15px]"
        >
            {crumbs.map((crumb, at) => {
                const last = at === crumbs.length - 1;

                return (
                    <Fragment key={crumb.to ?? crumb.label}>
                        {at > 0 && (
                            <ChevronRight size={14} className="shrink-0 text-ink-faint" />
                        )}

                        {crumb.to && !last ? (
                            <Link
                                to={crumb.to}
                                className="shrink-0 text-ink-muted transition-colors hover:text-ink"
                            >
                                {crumb.label}
                            </Link>
                        ) : (
                            <span className="truncate font-medium text-ink" aria-current="page">
                                {crumb.label}
                            </span>
                        )}
                    </Fragment>
                );
            })}
        </nav>
    );
}
