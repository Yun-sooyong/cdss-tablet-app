import { useState } from 'react';
import { Moon, Sun } from 'lucide-react';

import { UploadIndicator } from '@/components/upload/UploadIndicator';
import { CONTAINER } from './container';

export default function Header() {
    const [isDark, setIsDark] = useState(
        () => document.documentElement.classList.contains('dark'),
    );

    function toggleTheme() {
        const next = !isDark;
        setIsDark(next);
        document.documentElement.classList.toggle('dark', next);
    }

    return (
        <header className="h-14 shrink-0 border-b border-border bg-surface">
            <div className={`${CONTAINER} flex h-full items-center justify-between px-6`}>
                <div className="text-sm text-ink-muted">의료진용 판독 콘솔</div>

                <div className="flex items-center gap-3">
                    <UploadIndicator />

                    <button
                        type="button"
                        onClick={toggleTheme}
                        aria-label={isDark ? '라이트 모드로' : '다크 모드로'}
                        className="flex items-center gap-1.5 rounded-md border border-border px-2.5 py-1.5 text-xs text-ink-muted transition-colors hover:text-ink"
                    >
                        {isDark ? <Sun size={14} /> : <Moon size={14} />}
                        {isDark ? '라이트' : '다크'}
                    </button>

                    <div className="text-sm text-ink">doctor1</div>
                </div>
            </div>
        </header>
    );
}
