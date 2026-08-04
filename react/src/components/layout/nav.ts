import type { LucideIcon } from 'lucide-react';
import {
    Boxes,
    Building2,
    Inbox,
    KeyRound,
    LayoutDashboard,
    List,
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
    // title >> 묶음 이름. 렌더하지 않고 여백으로만 구분
    title : string;
    items : NavItem[];
}

// 로그인 signup 결과상세(/results/:jobId)는 네비에 넣지 않는다.
export const NAV_GROUPS : NavGroup[] = [
    {
        title: '분석',
        items: [
            { to: '/', label: '대시보드', icon: LayoutDashboard },
            { to: '/upload', label: '분석 요청', icon: Upload },
            { to: '/cases', label: '판독 목록', icon: List },
        ],
    },
    {
        title: '판독',
        items: [
            // 배지·컬럼·대시보드가 쓰는 말과 같아야 한다
            { to: '/review', label: '확인 필요', icon: Search, badge: 'review' },
        ],
    },
    {
        title: '협업',
        items: [
            { to: '/sharing', label: '보낸 공유', icon: Share2 },
            { to: '/shared', label: '받은 공유', icon: Inbox },
            { to: '/chat', label: '메시지', icon: MessageSquare },
        ],
    },
    {
        title: '관리',
        items: [
            { to: '/profile', label: '내 정보', icon: User },
        ],
    },
];

/* 관리 콘솔 사이드바 >> /admin */
export const ADMIN_NAV_GROUPS : NavGroup[] = [
    {
        title: '계정',
        items: [
            { to: '/admin/staff', label: '구성원', icon: Users },
            { to: '/admin/invitations', label: '초대코드', icon: KeyRound },
        ],
    },
    {
        title: '시스템',
        items: [
            { to: '/admin/models', label: '모델 버전', icon: Boxes },
            { to: '/admin/departments', label: '부서', icon: Building2 },
        ],
    },
    {
        title: '내',
        items: [
            { to: '/admin/profile', label: '내 정보', icon: User },
        ],
    },
];
