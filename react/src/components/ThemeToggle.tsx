import { useTheme } from 'next-themes';
import { Moon, Sun } from 'lucide-react';

/* 테마 전환 >> 헤더와 로그인 화면 공용 */
export function ThemeToggle() {
    const { resolvedTheme, setTheme } = useTheme();

    // 저장값을 읽기 전에는 resolvedTheme이 undefined다. 그동안 자리만 잡아 둔다
    const isDark = resolvedTheme === 'dark';

    return (
        <button
            type="button"
            onClick={() => setTheme(isDark ? 'light' : 'dark')}
            aria-label={isDark ? '라이트 모드로 전환' : '다크 모드로 전환'}
            className="flex h-8 items-center gap-1.5 rounded-md border border-border px-2.5 text-xs text-ink-muted transition-colors hover:text-ink"
        >
            {resolvedTheme ? (
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
