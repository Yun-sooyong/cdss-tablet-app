import { useEffect, useState } from 'react';
import { useTheme } from 'next-themes';
import { Moon, Sun } from 'lucide-react';

/* 테마 전환 >> 헤더와 로그인 화면 공용 */
export function ThemeToggle() {
    const { resolvedTheme, setTheme } = useTheme();

    // 서버 렌더가 아니어도 첫 페인트에는 저장값을 모른다. 확정 전까지 자리만 잡아 둔다
    const [ready, setReady] = useState(false);
    useEffect(() => setReady(true), []);

    const isDark = resolvedTheme === 'dark';

    return (
        <button
            type="button"
            onClick={() => setTheme(isDark ? 'light' : 'dark')}
            aria-label={isDark ? '라이트 모드로 전환' : '다크 모드로 전환'}
            className="flex h-8 items-center gap-1.5 rounded-md border border-border px-2.5 text-xs text-ink-muted transition-colors hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand"
        >
            {ready ? (
                <>
                    {isDark ? <Sun size={14} /> : <Moon size={14} />}
                    {isDark ? '라이트' : '다크'}
                </>
            ) : (
                <span className="w-10" />
            )}
        </button>
    );
}
