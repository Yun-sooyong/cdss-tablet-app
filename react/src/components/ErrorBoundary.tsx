import { Component } from 'react';
import type { ErrorInfo, ReactNode } from 'react';

import { BUTTON_SECONDARY } from '@/components/form';

// ErrorBoundary >> 없으면 렌더 예외 하나에 화면 전체가 백지가 된다
export class ErrorBoundary extends Component<
    { children : ReactNode },
    { error : Error | null }
> {
    state : { error : Error | null } = { error: null };

    static getDerivedStateFromError(error : Error) {
        return { error };
    }

    componentDidCatch(error : Error, info : ErrorInfo) {
        console.error('[ErrorBoundary]', error, info.componentStack);
    }

    render() {
        const { error } = this.state;
        if (!error) return this.props.children;

        return (
            <div role="alert" className="py-16 text-center">
                <p className="text-sm text-ink">화면을 그리지 못했습니다.</p>
                <p className="mt-1 font-mono text-xs text-ink-faint">{error.message}</p>

                <button
                    type="button"
                    onClick={() => this.setState({ error: null })}
                    className={`mt-4 ${BUTTON_SECONDARY}`}
                >
                    다시 시도
                </button>
            </div>
        );
    }
}