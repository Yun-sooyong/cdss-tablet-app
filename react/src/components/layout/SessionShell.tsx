import { Navigate, Outlet } from 'react-router-dom';

import { isAuthenticated } from '@/api';
import { AnalysisWatcher } from '@/components/AnalysisWatcher';
import { UploadProvider } from '@/components/upload/UploadProvider';

/* 세션 레이어 >> 두 콘솔 공통. 로그인 확인 · 업로드 큐 · 분석 폴링 */
export default function SessionShell() {
    if (!isAuthenticated()) return <Navigate to="/login" replace />;

    return (
        <UploadProvider>
            <Outlet />

            <AnalysisWatcher />
        </UploadProvider>
    );
}
