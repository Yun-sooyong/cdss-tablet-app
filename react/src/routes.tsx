import { Navigate, Route, Routes } from 'react-router-dom';

import AbstainReviewPage from '@/pages/AbstainReviewPage';
import CaseListPage from '@/pages/CaseListPage';
import ChatPage from '@/pages/ChatPage';
import DashboardPage from '@/pages/DashboardPage';
import LoginPage from '@/pages/LoginPage';
import NotFoundPage from '@/pages/NotFoundPage';
import NotificationsPage from '@/pages/NotificationsPage';
import ProfilePage from '@/pages/ProfilePage';
import ResultDetailPage from '@/pages/ResultDetailPage';
import ResultSummaryPage from '@/pages/ResultSummaryPage';
import SharedWithMePage from '@/pages/SharedWithMePage';
import SharingPage from '@/pages/SharingPage';
import SignUpPage from '@/pages/SignUpPage';
import UploadPage from '@/pages/UploadPage';
import AdminDepartmentsPage from '@/pages/admin/DepartmentsPage';
import AdminInvitationsPage from '@/pages/admin/InvitationsPage';
import AdminModelsPage from '@/pages/admin/ModelsPage';
import AdminStaffPage from '@/pages/admin/StaffPage';
import AdminShell from '@/components/layout/AdminShell';
import AppShell from '@/components/layout/AppShell';
import SessionShell from '@/components/layout/SessionShell';

/* 라우트 >> 상태는 URL 또는 서버에서만 관리 */
export default function AppRoutes() {
    return (
        <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/signup" element={<SignUpPage />} />

            <Route element={<SessionShell />}>
                {/* 관리 콘솔 >> AppShell의 * 보다 먼저 */}
                <Route path="/admin" element={<AdminShell />}>
                    <Route index element={<Navigate to="/admin/staff" replace />} />
                    <Route path="staff" element={<AdminStaffPage />} />
                    <Route path="invitations" element={<AdminInvitationsPage />} />
                    <Route path="models" element={<AdminModelsPage />} />
                    <Route path="departments" element={<AdminDepartmentsPage />} />

                    {/* 관리자는 판독 콘솔에 못 들어가므로 자기 화면도 여기 걸어 둔다 */}
                    <Route path="profile" element={<ProfilePage />} />
                    <Route path="notifications" element={<NotificationsPage />} />
                </Route>

                <Route element={<AppShell />}>
                    <Route path="/" element={<DashboardPage />} />
                    <Route path="/upload" element={<UploadPage />} />
                    <Route path="/cases" element={<CaseListPage />} />
                    <Route path="/review" element={<AbstainReviewPage />} />
                    <Route path="/batches/:batchId" element={<ResultSummaryPage />} />
                    <Route path="/results/:jobId" element={<ResultDetailPage />} />
                    <Route path="/sharing" element={<SharingPage />} />
                    <Route path="/shared" element={<SharedWithMePage />} />
                    <Route path="/chat" element={<ChatPage />} />
                    <Route path="/notifications" element={<NotificationsPage />} />
                    <Route path="/profile" element={<ProfilePage />} />
                    <Route path="*" element={<NotFoundPage />} />
                </Route>
            </Route>
        </Routes>
    );
}
