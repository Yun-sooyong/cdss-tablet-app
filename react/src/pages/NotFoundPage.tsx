import { Link } from 'react-router-dom';

export default function NotFoundPage() {
    return (
        <div className="py-16 text-center">
            <p className="text-sm text-ink-faint">페이지를 찾을 수 없습니다.</p>
            <Link
                to="/"
                className="mt-4 inline-block text-sm text-ink-muted underline-offset-2 transition-colors hover:text-ink hover:underline"
            >
                대시보드로
            </Link>
        </div>
    );
}
