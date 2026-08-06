import type { LucideIcon } from 'lucide-react';
import {
    Bell,
    Boxes,
    Building2,
    LayoutDashboard,
    List,
    Pill,
    ScanEye,
    Share2,
    Stethoscope,
    Upload,
    User,
    UserPlus,
    Users,
} from 'lucide-react';

export interface NavItem {
    to : string;
    label : string;
    icon : LucideIcon;
    // badge >> 사이드바에 건수를 띄울 항목
    badge? : 'review' | 'unread' | 'requests';
}

export interface NavGroup {
    // title >> 렌더하지 않는다. 그룹 사이는 구분선으로 나눈다
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
            // 배지·컬럼·대시보드가 쓰는 말과 같아야 한다
            { to: '/review', label: '확인 필요', icon: ScanEye, badge: 'review' },
        ],
    },
    {
        title: '진료',
        items: [
            { to: '/visits', label: '진료 기록', icon: Stethoscope },
            { to: '/prescriptions', label: '처방', icon: Pill },
        ],
    },
    {
        title: '협업',
        items: [{ to: '/sharing', label: '공유', icon: Share2 }],
    },
    {
        title: '개인',
        items: [
            { to: '/notifications', label: '알림', icon: Bell, badge: 'unread' },
            { to: '/profile', label: '내 정보', icon: User },
        ],
    },
];

/* 관리 콘솔 사이드바 >> /admin */
export const ADMIN_NAV_GROUPS : NavGroup[] = [
    {
        title: '구성원',
        items: [
            { to: '/admin/staff', label: '구성원', icon: Users },
            { to: '/admin/requests', label: '계정 요청', icon: UserPlus, badge: 'requests' },
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
        title: '개인',
        items: [
            { to: '/admin/notifications', label: '알림', icon: Bell, badge: 'unread' },
            { to: '/admin/profile', label: '내 정보', icon: User },
        ],
    },
];
