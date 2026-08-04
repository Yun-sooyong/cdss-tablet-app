import type { LucideIcon } from 'lucide-react';
import {
    Bell,
    CircleAlert,
    FileText,
    Inbox,
    LayoutDashboard,
    List,
    Loader,
    MessageSquare,
    Search,
    Share2,
    Upload,
    User,
    Users,
} from 'lucide-react';

export interface NavItem {
    to : string;
    label : string;
    icon : LucideIcon;
    // badge >> 사이드바에 건수를 띄울 항목
    badge? : 'review';
}

export interface NavGroup {
    title : string;
    items : NavItem[];
}

// 로그인 signup 결과상세(/results/:jobId)는 네비에 넣지 않는다.
export const NAV_GROUPS : NavGroup[] = [
    {
        title: '분석',
        items: [
            { to: '/', label: '대시보드', icon: LayoutDashboard },
            { to: '/upload', label: '업로드', icon: Upload },
            { to: '/processing', label: '처리 중', icon: Loader },
            { to: '/cases', label: '케이스 목록', icon: List },
        ],
    },
    {
        title: '판독',
        items: [
            { to: '/review', label: '판정 유보 검증함', icon: Search, badge: 'review' },
            { to: '/results', label: '결과 요약', icon: FileText },
            { to: '/errors', label: '오류 목록', icon: CircleAlert },
        ],
    },
    {
        title: '협업',
        items: [
            { to: '/sharing', label: '공유 보내기', icon: Share2 },
            { to: '/shared', label: '공유받은 항목', icon: Inbox },
            { to: '/chat', label: '채팅', icon: MessageSquare },
        ],
    },
    {
        title: '관리',
        items: [
            { to: '/notifications', label: '알림', icon: Bell },
            { to: '/staff', label: '회원 관리', icon: Users },
            { to: '/profile', label: '내 정보', icon: User },
        ],
    },
];
