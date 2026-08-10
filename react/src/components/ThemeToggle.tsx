import { useTheme } from 'next-themes';
import { Moon, Sun } from 'lucide-react';

/* 테마 전환 >> 사이드바 하단과 로그인 화면 공용 */
export function ThemeToggle({ iconOnly } : { iconOnly? : boolean }) {
    const { resolvedTheme, setTheme } = useTheme();

    // 저장값을 읽기 전에는 resolvedTheme이 undefined다. 그동안 자리만 잡아 둔다
    const isDark = resolvedTheme === 'dark';
    const label = isDark ? '라이트 모드로 전환' : '다크 모드로 전환';

    if (iconOnly) {
        return (
            <button
                type="button"
                onClick={() => setTheme(isDark ? 'light' : 'dark')}
                aria-label={label}
                title={label}
                className="flex size-7 shrink-0 items-center justify-center rounded-md text-ink-muted transition-colors hover:bg-ink/[0.04] hover:text-ink"
            >
                {resolvedTheme && (isDark ? <Sun size={15} /> : <Moon size={15} />)}
            </button>
        );
    }

    return (
        <button
            type="button"
            onClick={() => setTheme(isDark ? 'light' : 'dark')}
            aria-label={label}
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
