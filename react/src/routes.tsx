import { Route, Routes } from 'react-router-dom';

import AbstainReviewPage from '@/pages/AbstainReviewPage';
import CaseListPage from '@/pages/CaseListPage';
import ChatPage from '@/pages/ChatPage';
import DashboardPage from '@/pages/DashboardPage';
import ErrorListPage from '@/pages/ErrorListPage';
import LoginPage from '@/pages/LoginPage';
import NotFoundPage from '@/pages/NotFoundPage';
import NotificationsPage from '@/pages/NotificationsPage';
import ProcessingPage from '@/pages/ProcessingPage';
import ProfilePage from '@/pages/ProfilePage';
import ResultDetailPage from '@/pages/ResultDetailPage';
import ResultSummaryPage from '@/pages/ResultSummaryPage';
import SharedWithMePage from '@/pages/SharedWithMePage';
import SharingPage from '@/pages/SharingPage';
import SignUpPage from '@/pages/SignUpPage';
import StaffAdminPage from '@/pages/StaffAdminPage';
import UploadPage from '@/pages/UploadPage';
import AppShell from '@/components/layout/AppShell';

// 상태는 URL 또는 서버에서만 관리 
export default function AppRoutes() {
    return (
        <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/signup" element={<SignUpPage />} />
            <Route element = {<AppShell/>}>
                <Route path="/" element={<DashboardPage />} />   
                <Route path="/upload" element={<UploadPage />} />
                <Route path="/processing" element={<ProcessingPage />} />
                <Route path="/cases" element={<CaseListPage />} />
                <Route path="/review" element={<AbstainReviewPage />} />
                <Route path="/errors" element={<ErrorListPage />} />
                <Route path="/results" element={<ResultSummaryPage />} />
                <Route path="/results/:jobId" element={<ResultDetailPage />} />
                <Route path="/sharing" element={<SharingPage />} />
                <Route path="/shared" element={<SharedWithMePage />} />
                <Route path="/chat" element={<ChatPage />} />
                <Route path="/notifications" element={<NotificationsPage />} />
                <Route path="/staff" element={<StaffAdminPage />} />
                <Route path="/profile" element={<ProfilePage />} />
                <Route path="*" element={<NotFoundPage />} />
            </Route>
        </Routes>
    );
}
