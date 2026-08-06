import { lazy } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';

import LoginPage from '@/pages/LoginPage';
import NotFoundPage from '@/pages/NotFoundPage';
import SignUpPage from '@/pages/SignUpPage';
import AdminShell from '@/components/layout/AdminShell';
import AppShell from '@/components/layout/AppShell';
import SessionShell from '@/components/layout/SessionShell';

const AbstainReviewPage = lazy(() => import('@/pages/AbstainReviewPage'));
const CaseListPage = lazy(() => import('@/pages/CaseListPage'));
const DashboardPage = lazy(() => import('@/pages/DashboardPage'));
const NotificationsPage = lazy(() => import('@/pages/NotificationsPage'));
const PrescriptionsPage = lazy(() => import('@/pages/PrescriptionsPage'));
const VisitsPage = lazy(() => import('@/pages/VisitsPage'));
const ProfilePage = lazy(() => import('@/pages/ProfilePage'));
const ResultDetailPage = lazy(() => import('@/pages/ResultDetailPage'));
const ResultSummaryPage = lazy(() => import('@/pages/ResultSummaryPage'));
const SharingPage = lazy(() => import('@/pages/SharingPage'));
const UploadPage = lazy(() => import('@/pages/UploadPage'));
const AdminDepartmentsPage = lazy(() => import('@/pages/admin/DepartmentsPage'));
const AdminAccountRequestsPage = lazy(() => import('@/pages/admin/AccountRequestsPage'));
const AdminModelsPage = lazy(() => import('@/pages/admin/ModelsPage'));
const AdminStaffPage = lazy(() => import('@/pages/admin/StaffPage'));

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
                    <Route path="requests" element={<AdminAccountRequestsPage />} />
                    <Route path="models" element={<AdminModelsPage />} />
                    <Route path="departments" element={<AdminDepartmentsPage />} />

                    {/* 관리자 */}
                    <Route path="profile" element={<ProfilePage />} />
                    <Route path="notifications" element={<NotificationsPage scope="admin" />} />
                </Route>

                <Route element={<AppShell />}>
                    <Route path="/" element={<DashboardPage />} />
                    <Route path="/upload" element={<UploadPage />} />
                    <Route path="/cases" element={<CaseListPage />} />
                    <Route path="/review" element={<AbstainReviewPage />} />
                    <Route path="/batches/:batchId" element={<ResultSummaryPage />} />
                    <Route path="/results/:jobId" element={<ResultDetailPage />} />
                    <Route path="/visits" element={<VisitsPage />} />
                    <Route path="/prescriptions" element={<PrescriptionsPage />} />
                    <Route path="/sharing" element={<SharingPage />} />
                    <Route path="/notifications" element={<NotificationsPage />} />
                    <Route path="/profile" element={<ProfilePage />} />
                    <Route path="*" element={<NotFoundPage />} />
                </Route>
            </Route>
        </Routes>
    );
}
