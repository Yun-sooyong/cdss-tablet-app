import type { ReactNode } from 'react';

import { ThemeToggle } from '@/components/ThemeToggle';
import { Logo } from '@/components/Logo';
import { APP_NAME } from '@/lib/app';

// 셸 밖 라우트라 사이드바 헤더가 없다. 01 17이 같은 틀을 쓴다
export default function AuthShell({
    title,
    description,
    children,
    footer,
} : {
    title : string;
    description : string;
    children : ReactNode;
    footer? : ReactNode;
}) {
    return (
        <div className="flex min-h-dvh items-center justify-center bg-bg-sunken px-6 py-12 text-foreground">
            <div className="grid w-full max-w-4xl overflow-hidden rounded-3xl border border-border bg-background shadow-sm md:grid-cols-2">
                {/* 로고 면 >> 좁은 화면에서는 폼 위로 접힌다 */}
                <div className="flex flex-col items-center justify-center gap-3 px-8 py-10">
                    <Logo className="w-full max-w-64 shrink-0 text-logo" />
                    <span className="text-2xl font-semibold tracking-[0.2em] text-logo">
                        {APP_NAME}
                    </span>
                </div>

                <div className="flex flex-col justify-center border-border bg-surface px-8 py-10 md:border-l">
                    <h1 className="text-xl font-semibold">{title}</h1>
                    <p className="mt-1.5 text-sm text-ink-muted">{description}</p>

                    <div className="mt-6">{children}</div>

                    {footer && (
                        <div className="mt-6 border-t border-border pt-5 text-sm text-ink-muted">
                            {footer}
                        </div>
                    )}

                    <div className="mt-6 flex justify-center">
                        <ThemeToggle />
                    </div>
                </div>
            </div>
        </div>
    );
}

export function Field({
    label,
    children,
} : {
    label : string;
    children : ReactNode;
}) {
    return (
        <label className="block">
            <span className="mb-1.5 block text-sm text-ink-muted">{label}</span>
            {children}
        </label>
    );
}

export { FIELD_INPUT, FIELD_SUBMIT } from '@/components/form';
