/* 쿼리 로딩 · 실패 표시 >> 빈 상태와 같은 자리 같은 크기 */
export function Pending({ label = '불러오는 중입니다.' } : { label? : string }) {
    return (
        <div role="status" className="py-16 text-center text-sm text-ink-faint">
            {label}
        </div>
    );
}

export function Failed({
    error,
    onRetry,
} : {
    error : unknown;
    onRetry? : () => void;
}) {
    const message = error instanceof Error ? error.message : '불러오지 못했습니다.';

    return (
        <div role="alert" className="py-16 text-center">
            <p className="text-sm text-ink-faint">{message}</p>

            {onRetry && (
                <button
                    type="button"
                    onClick={onRetry}
                    className="mt-4 h-10 rounded-md border border-border px-4 text-sm text-ink-muted transition-colors hover:text-ink"
                >
                    다시 시도
                </button>
            )}
        </div>
    );
}
