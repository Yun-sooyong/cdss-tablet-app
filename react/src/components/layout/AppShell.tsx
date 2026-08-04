import { Navigate, Outlet } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';

import { getMe } from '@/api';
import { qk } from '@/api/keys';
import Header from './Header';
import Sidebar from './Sidebar';
import { CONTAINER } from './container';
import { NAV_GROUPS } from './nav';

/* 판독 콘솔 셸 >> 의료진용 */
export default function AppShell() {
    const { data: me, isPending } = useQuery({ queryKey: qk.me, queryFn: getMe });

    if (isPending) return null;
    if (me?.role === 'admin') return <Navigate to="/admin" replace />;

    return (
        <div className="flex min-h-dvh bg-background text-foreground">
            <Sidebar groups={NAV_GROUPS} />

            <div className="flex min-h-dvh flex-1 flex-col">
                <Header />
                <main className="flex-1 overflow-auto">
                    <div className={CONTAINER + ' p-6'}>
                        <Outlet />
                    </div>
                </main>
            </div>
        </div>
    );
}
