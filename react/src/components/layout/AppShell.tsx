import { Suspense } from 'react';
import { Navigate, Outlet } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';

import { getMe } from '@/api';
import { qk } from '@/api/keys';
import { ErrorBoundary } from '@/components/ErrorBoundary';
import { Pending } from '@/components/QueryState';
import Breadcrumb from './Breadcrumb';
import Sidebar, { NavDrawer } from './Sidebar';
import { CONTAINER } from './container';
import { NAV_GROUPS } from './nav';

/* 판독 콘솔 셸 >> 의료진용 */
export default function AppShell() {
    const { data: me, isPending } = useQuery({ queryKey: qk.me, queryFn: getMe });

    // 역할을 알기 전에 셸을 그리면 관리자에게 판독 사이드바가 깜빡인다
    if (isPending) {
        return (
            <div className="flex min-h-dvh items-center justify-center bg-background">
                <Pending />
            </div>
        );
    }

    if (me?.role === 'admin') return <Navigate to="/admin" replace />;

    return (
        <div className="flex h-dvh bg-background text-foreground">
            <Sidebar groups={NAV_GROUPS} />

            <main className="flex-1 overflow-auto">
                <div className={CONTAINER + ' p-6'}>
                    {/* 드로어 트리거는 lg 미만에서만 보인다 */}
                    <div className="mb-3 lg:hidden">
                        <NavDrawer groups={NAV_GROUPS} />
                    </div>

                    <Breadcrumb />

                    <ErrorBoundary>
                        <Suspense fallback={<Pending />}>
                            <Outlet />
                        </Suspense>
                    </ErrorBoundary>
                </div>
            </main>
        </div>
    );
}
