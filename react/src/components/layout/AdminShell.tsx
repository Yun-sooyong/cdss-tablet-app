import { Navigate, Outlet } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';

import { getMe } from '@/api';
import { qk } from '@/api/keys';
import { Pending } from '@/components/QueryState';
import Header from './Header';
import Sidebar, { NavDrawer } from './Sidebar';
import { CONTAINER } from './container';
import { ADMIN_NAV_GROUPS } from './nav';

/* 관리 콘솔 셸 >> /admin 아래. 관리자 전용 */
export default function AdminShell() {
    const { data: me, isPending } = useQuery({ queryKey: qk.me, queryFn: getMe });

    if (isPending) {
        return (
            <div className="flex min-h-dvh items-center justify-center bg-admin-bg">
                <Pending />
            </div>
        );
    }

    if (me?.role !== 'admin') return <Navigate to="/" replace />;

    return (
        <div className="flex min-h-dvh bg-admin-bg text-foreground">
            <Sidebar groups={ADMIN_NAV_GROUPS} tone="admin" subtitle="관리" />

            <div className="flex min-h-dvh flex-1 flex-col">
                <Header
                    base="/admin"
                    tone="admin"
                    nav={
                        <NavDrawer groups={ADMIN_NAV_GROUPS} tone="admin" subtitle="관리" />
                    }
                />
                <main className="flex-1 overflow-auto">
                    <div className={CONTAINER + ' p-6'}>
                        <Outlet />
                    </div>
                </main>
            </div>
        </div>
    );
}
