import { useState } from 'react';
import type { ReactNode } from 'react';
import { NavLink } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Menu } from 'lucide-react';

import { getLatestJobs } from '@/api';
import { qk } from '@/api/keys';
import { ICON_BUTTON } from '@/components/form';
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet';
import { needsReview } from '@/lib/decision';
import { cn } from '@/lib/utils';
import type { NavGroup } from './nav';

// TONE >> 콘솔별 배색. brand는 판독, admin은 관리
const TONE = {
    brand: {
        aside: 'bg-sidebar',
        dot: 'bg-brand',
        subtitle: 'text-ink-faint',
        active: 'bg-brand-soft font-medium text-ink',
        idle: 'text-ink-muted hover:bg-brand-soft/60 hover:text-ink',
    },
    admin: {
        aside: 'bg-admin-soft',
        dot: 'bg-admin',
        subtitle: 'font-medium text-admin',
        active: 'bg-admin/15 font-medium text-ink',
        idle: 'text-ink-muted hover:bg-admin/10 hover:text-ink',
    },
} as const;

type Tone = keyof typeof TONE;

interface NavProps {
    groups : NavGroup[];
    // subtitle >> 브랜드 옆 콘솔 이름
    subtitle? : string;
    footer? : ReactNode;
    tone? : Tone;
}

// 사이드바 >> lg 이상. 그 아래는 NavDrawer가 대신한다
export default function Sidebar({ groups, subtitle, footer, tone = 'brand' } : NavProps) {
    return (
        <aside
            className={cn(
                'hidden w-60 shrink-0 flex-col border-r border-border lg:flex',
                TONE[tone].aside,
            )}
        >
            <Brand subtitle={subtitle} tone={tone} />
            <NavList groups={groups} tone={tone} />

            {footer && <div className="border-t border-border px-5 py-4">{footer}</div>}
        </aside>
    );
}

// NavDrawer >> lg 미만. 헤더의 햄버거로 연다
export function NavDrawer({ groups, subtitle, footer, tone = 'brand' } : NavProps) {
    const [open, setOpen] = useState(false);

    return (
        <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger
                aria-label="메뉴 열기"
                className={`lg:hidden ${ICON_BUTTON}`}
            >
                <Menu size={18} />
            </SheetTrigger>

            <SheetContent
                side="left"
                showCloseButton={false}
                className={cn('w-64 gap-0 sm:max-w-64', TONE[tone].aside)}
            >
                <Brand subtitle={subtitle} tone={tone} />

                {/* 항목을 고르면 닫는다. 안 그러면 서랍이 화면을 덮은 채로 남는다 */}
                <NavList groups={groups} tone={tone} onNavigate={() => setOpen(false)} />

                {footer && <div className="border-t border-border px-5 py-4">{footer}</div>}
            </SheetContent>
        </Sheet>
    );
}

function Brand({ subtitle, tone } : { subtitle? : string; tone : Tone }) {
    return (
        <div className="flex items-center gap-2 border-b border-border px-5 py-4">
            <span className={cn('size-2.5 rounded-full', TONE[tone].dot)} />
            <span className="text-sm font-semibold tracking-tight">sTIL CDSS</span>
            {subtitle && (
                <span className={cn('text-sm', TONE[tone].subtitle)}>{subtitle}</span>
            )}
        </div>
    );
}

function NavList({
    groups,
    tone,
    onNavigate,
} : {
    groups : NavGroup[];
    tone : Tone;
    onNavigate? : () => void;
}) {
    const skin = TONE[tone];

    // 확인 필요 배지
    const { data: jobs } = useQuery({ queryKey: qk.latestJobs, queryFn: getLatestJobs });
    const reviewCount = jobs?.filter((job) => needsReview(job.result)).length ?? 0;

    return (
        <nav className="flex-1 overflow-y-auto px-3 py-4">
            {groups.map((group) => (
                <div key={group.title} className="mb-5 last:mb-0">
                    {group.items.map((item) => {
                        const Icon = item.icon;
                        const count = item.badge === 'review' ? reviewCount : 0;

                        return (
                            <NavLink
                                key={item.to}
                                to={item.to}
                                end={item.to === '/'}
                                onClick={onNavigate}
                                className={({ isActive }) =>
                                    cn(
                                        'flex items-center justify-between rounded-md px-2 py-2 text-sm transition-colors',
                                        isActive ? skin.active : skin.idle,
                                    )
                                }
                            >
                                <span className="flex items-center gap-2">
                                    <Icon size={15} />
                                    {item.label}
                                </span>

                                {count > 0 && (
                                    <span className="rounded-full bg-decision-abstain/18 px-1.5 py-0.5 text-[11px] font-semibold text-decision-abstain">
                                        {count}
                                    </span>
                                )}
                            </NavLink>
                        );
                    })}
                </div>
            ))}
        </nav>
    );
}
