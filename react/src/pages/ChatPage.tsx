import { Link } from 'react-router-dom';

// 14 메시지 >> 보류. 실시간 방식 미정
export default function ChatPage() {
    return (
        <div className="py-16 text-center">
            <p className="text-sm text-ink-faint">준비 중입니다</p>
            <Link
                to="/"
                className="mt-4 inline-block text-sm text-ink-muted underline-offset-2 transition-colors hover:text-ink hover:underline"
            >
                대시보드로
            </Link>
        </div>
    );
}
