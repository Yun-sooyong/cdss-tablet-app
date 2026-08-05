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
        <div className="flex min-h-dvh items-center justify-center bg-background px-6 py-12 text-foreground">
            <div className="w-full max-w-sm">
                <div className="mb-8 flex items-center gap-2">
                    <Logo className="size-6 shrink-0 text-logo" />
                    <span className="text-sm font-semibold tracking-tight">{APP_NAME}</span>
                    <span className="ml-auto">
                        <ThemeToggle />
                    </span>
                </div>

                <h1 className="text-xl font-semibold">{title}</h1>
                <p className="mt-1.5 text-sm text-ink-muted">{description}</p>

                <div className="mt-6">{children}</div>

                {footer && (
                    <div className="mt-6 border-t border-border pt-5 text-sm text-ink-muted">
                        {footer}
                    </div>
                )}
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
