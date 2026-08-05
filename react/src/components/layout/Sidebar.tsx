import { useEffect, useState } from 'react';
import { Link, NavLink } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { Menu, PanelLeftClose, PanelLeftOpen } from 'lucide-react';

import { getAccountRequests, getLatestJobs, getMe, getNotifications } from '@/api';
import { qk } from '@/api/keys';
import { Logo } from '@/components/Logo';
import { ThemeToggle } from '@/components/ThemeToggle';
import { UploadIndicator } from '@/components/upload/UploadIndicator';
import { Sheet, SheetContent, SheetTrigger } from '@/components/ui/sheet';
import { APP_NAME } from '@/lib/app';
import { needsReview } from '@/lib/decision';
import { unreadIn } from '@/lib/notification';
import { ROLE_LABEL } from '@/lib/staff';
import { cn } from '@/lib/utils';
import type { NavGroup } from './nav';

// TONE >> 콘솔별 배색. brand는 판독, admin은 관리
const TONE = {
    brand: {
        aside: 'bg-sidebar',
        active: 'bg-brand-soft font-semibold text-ink',
        icon: 'text-brand',
        chip: 'bg-brand-soft text-brand',
    },
    admin: {
        aside: 'bg-admin-soft',
        active: 'bg-admin/12 font-semibold text-ink',
        icon: 'text-admin',
        chip: 'bg-admin/12 text-admin',
    },
} as const;

type Tone = keyof typeof TONE;

// 호버는 무채색 >> 브랜드 틴트가 '선택됨'만 뜻하게 한다
const IDLE = 'text-ink-muted hover:bg-ink/[0.04] hover:text-ink';

// BADGE_TONE >> 주목색은 판정 유보에만 준다
const BADGE_TONE = {
    review: { dot: 'bg-decision-abstain', pill: 'bg-decision-abstain/18 text-decision-abstain' },
    unread: { dot: 'bg-brand', pill: 'bg-brand-soft text-brand' },
    requests: { dot: 'bg-admin', pill: 'bg-admin/15 text-admin' },
} as const;

const COLLAPSE_KEY = 'cdss.sidebar.collapsed';

interface NavProps {
    groups : NavGroup[];
    subtitle? : string;
    tone? : Tone;
}

// 사이드바 >> lg 이상. 그 아래는 NavDrawer가 대신한다
export default function Sidebar({ groups, subtitle, tone = 'brand' } : NavProps) {
    const [collapsed, setCollapsed] = useState(
        () => localStorage.getItem(COLLAPSE_KEY) === '1',
    );

    useEffect(() => {
        localStorage.setItem(COLLAPSE_KEY, collapsed ? '1' : '0');
    }, [collapsed]);

    return (
        <aside
            className={cn(
                'hidden shrink-0 flex-col border-r border-border transition-[width] duration-150 lg:flex',
                collapsed ? 'w-14' : 'w-60',
                TONE[tone].aside,
            )}
        >
            <Brand
                subtitle={subtitle}
                tone={tone}
                collapsed={collapsed}
                onToggle={() => setCollapsed((v) => !v)}
            />
            <NavList groups={groups} tone={tone} collapsed={collapsed} />
            <Foot tone={tone} collapsed={collapsed} />
        </aside>
    );
}

// NavDrawer >> lg 미만. 항상 펼친 모양으로 연다
export function NavDrawer({ groups, subtitle, tone = 'brand' } : NavProps) {
    const [open, setOpen] = useState(false);

    return (
        <Sheet open={open} onOpenChange={setOpen}>
            <SheetTrigger
                aria-label="메뉴 열기"
                className="flex size-8 items-center justify-center rounded-md text-ink-muted transition-colors hover:bg-ink/[0.04] hover:text-ink lg:hidden"
            >
                <Menu size={18} />
            </SheetTrigger>

            <SheetContent
                side="left"
                showCloseButton={false}
                className={cn('w-64 gap-0 sm:max-w-64', TONE[tone].aside)}
            >
                <Brand subtitle={subtitle} tone={tone} />
                <NavList groups={groups} tone={tone} onNavigate={() => setOpen(false)} />
                <Foot tone={tone} />
            </SheetContent>
        </Sheet>
    );
}

function Brand({
    subtitle,
    tone,
    collapsed,
    onToggle,
} : {
    subtitle? : string;
    tone : Tone;
    collapsed? : boolean;
    onToggle? : () => void;
}) {
    return (
        <div
            className={cn(
                'flex h-14 shrink-0 items-center border-b border-border',
                collapsed ? 'justify-center px-2' : 'gap-2 px-3',
            )}
        >
            {collapsed && onToggle ? (
                <button
                    type="button"
                    onClick={onToggle}
                    aria-label="사이드바 펼치기"
                    title="사이드바 펼치기"
                    className="flex size-8 items-center justify-center rounded-md text-ink-muted transition-colors hover:bg-ink/[0.04] hover:text-ink"
                >
                    <PanelLeftOpen size={16} />
                </button>
            ) : (
                <>
                    <Logo className="size-6 shrink-0 text-logo" />
                    <span className="text-sm font-semibold tracking-tight">{APP_NAME}</span>
                    {subtitle && (
                        <span
                            className={cn(
                                'rounded px-1.5 py-0.5 text-[11px] font-medium',
                                TONE[tone].chip,
                            )}
                        >
                            {subtitle}
                        </span>
                    )}

                    {onToggle && (
                        <button
                            type="button"
                            onClick={onToggle}
                            aria-label="사이드바 접기"
                            title="사이드바 접기"
                            className="ml-auto flex size-7 items-center justify-center rounded-md text-ink-faint transition-colors hover:bg-ink/[0.04] hover:text-ink"
                        >
                            <PanelLeftClose size={16} />
                        </button>
                    )}
                </>
            )}
        </div>
    );
}

function NavList({
    groups,
    tone,
    collapsed,
    onNavigate,
} : {
    groups : NavGroup[];
    tone : Tone;
    collapsed? : boolean;
    onNavigate? : () => void;
}) {
    // 배지를 실제로 그리는 항목이 있을 때만 부른다. 관리 콘솔엔 확인 필요 배지가 없다
    const needs = new Set(groups.flatMap((g) => g.items.map((i) => i.badge)));

    const { data: jobs } = useQuery({
        queryKey: qk.latestJobs,
        queryFn: getLatestJobs,
        enabled: needs.has('review'),
    });
    const { data: notifications } = useQuery({
        queryKey: qk.notifications,
        queryFn: getNotifications,
        enabled: needs.has('unread'),
    });
    const { data: requests } = useQuery({
        queryKey: qk.accountRequests('pending'),
        queryFn: () => getAccountRequests('pending'),
        enabled: needs.has('requests'),
    });

    const count = {
        review: jobs?.filter((job) => needsReview(job.result)).length ?? 0,
        // 배지와 알림 화면이 같은 것을 세야 한다
        unread: unreadIn(notifications, tone === 'admin' ? 'admin' : 'clinical'),
        requests: requests?.length ?? 0,
    };

    return (
        <nav className={cn('flex-1 overflow-y-auto py-3', collapsed ? 'px-2' : 'px-3')}>
            {groups.map((group, at) => (
                <div key={group.title}>
                    {at > 0 && <div className="my-2 h-px bg-border" />}

                    <div className="flex flex-col gap-0.5">
                        {group.items.map((item) => {
                            const Icon = item.icon;
                            const badge = item.badge ? count[item.badge] : 0;
                            const badgeTone = BADGE_TONE[item.badge ?? 'review'];

                            return (
                                <NavLink
                                    key={item.to}
                                    to={item.to}
                                    end={item.to === '/'}
                                    onClick={onNavigate}
                                    title={collapsed ? item.label : undefined}
                                    className={({ isActive }) =>
                                        cn(
                                            'flex h-8 items-center rounded-md text-sm transition-colors',
                                            collapsed ? 'justify-center' : 'gap-2.5 px-2.5',
                                            isActive ? TONE[tone].active : IDLE,
                                        )
                                    }
                                >
                                    {({ isActive }) => (
                                        <>
                                            <span className="relative flex shrink-0 items-center">
                                                <Icon
                                                    size={16}
                                                    className={
                                                        isActive ? TONE[tone].icon : 'text-ink-faint'
                                                    }
                                                />
                                                {/* 접히면 숫자 대신 점 */}
                                                {collapsed && badge > 0 && (
                                                    <span
                                                        className={cn(
                                                            'absolute -right-0.5 -top-0.5 size-1.5 rounded-full',
                                                            badgeTone.dot,
                                                        )}
                                                    />
                                                )}
                                            </span>

                                            {!collapsed && (
                                                <>
                                                    <span className="flex-1 truncate">
                                                        {item.label}
                                                    </span>
                                                    {badge > 0 && (
                                                        <span
                                                            className={cn(
                                                                'inline-flex h-[18px] min-w-5 items-center justify-center rounded-full px-1.5 text-[11px] font-bold tabular-nums',
                                                                badgeTone.pill,
                                                            )}
                                                        >
                                                            {badge > 99 ? '99+' : badge}
                                                        </span>
                                                    )}
                                                </>
                                            )}
                                        </>
                                    )}
                                </NavLink>
                            );
                        })}
                    </div>
                </div>
            ))}
        </nav>
    );
}

function Foot({ tone, collapsed } : { tone : Tone; collapsed? : boolean }) {
    const { data: me } = useQuery({ queryKey: qk.me, queryFn: getMe });

    const base = tone === 'admin' ? '/admin' : '';
    const initial = me?.username?.[0]?.toUpperCase() ?? '-';
    const role = me ? `${me.department || '소속 미지정'} · ${ROLE_LABEL[me.role]}` : '';

    return (
        <div className={cn('shrink-0 pb-3', collapsed ? 'px-2' : 'px-3')}>
            <UploadIndicator collapsed={collapsed} />

            <div className="my-2 h-px bg-border" />

            <div className={cn('flex items-center gap-1', collapsed && 'flex-col')}>
                <Link
                    to={`${base}/profile`}
                    title={collapsed ? `${me?.username ?? ''} · ${role}` : undefined}
                    className={cn(
                        'flex min-w-0 items-center gap-2 rounded-md p-1 transition-colors hover:bg-ink/[0.04]',
                        !collapsed && 'flex-1',
                    )}
                >
                    <span
                        className={cn(
                            'flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-bold',
                            TONE[tone].chip,
                        )}
                    >
                        {initial}
                    </span>

                    {!collapsed && (
                        <span className="min-w-0 flex-1">
                            <span className="block truncate text-xs font-semibold text-ink">
                                {me?.username ?? '-'}
                            </span>
                            <span className="block truncate text-[11px] text-ink-muted">
                                {role}
                            </span>
                        </span>
                    )}
                </Link>

                <ThemeToggle iconOnly />
            </div>
        </div>
    );
}
