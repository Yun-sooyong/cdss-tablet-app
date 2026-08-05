// 실제 이미지가 아님을 판독자에게 알린다. src/dev 와 함께 사라진다
export function PlaceholderBadge() {
    return (
        <div
            role="alert"
            className="pointer-events-none absolute left-3 top-3 rounded-md bg-danger px-2.5 py-1 text-xs font-medium text-white"
        >
            예시 이미지 · 실제 슬라이드가 아닙니다
        </div>
    );
}