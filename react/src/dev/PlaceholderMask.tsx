// 세그멘테이션 마스크를 흉내낸 SVG. seg 토큰 색을 그대로 써서 범례와 맞춘다.
// 배경이 투명해야 원본 위에 겹쳤을 때 투명도 슬라이더가 의도대로 동작한다.
const REGIONS = [
    { d: 'M 0 0 H 46 V 34 Q 26 44 0 36 Z', token: 'var(--seg-tumor)' },
    { d: 'M 46 0 H 100 V 30 Q 74 40 46 34 Z', token: 'var(--seg-stroma)' },
    { d: 'M 0 36 Q 26 44 46 34 V 72 Q 22 80 0 70 Z', token: 'var(--seg-tils)' },
    { d: 'M 46 34 Q 74 40 100 30 V 66 Q 70 76 46 72 Z', token: 'var(--seg-tumor)' },
    { d: 'M 0 70 Q 22 80 46 72 V 100 H 0 Z', token: 'var(--seg-stroma)' },
    { d: 'M 46 72 Q 70 76 100 66 V 100 H 46 Z', token: 'var(--seg-tils)' },
];

export function PlaceholderMask({ className }: { className?: string }) {
    return (
        <svg viewBox="0 0 100 100" className={className} preserveAspectRatio="none">
            {REGIONS.map((r, i) => (
                <path key={i} d={r.d} fill={r.token} opacity={0.55} />
            ))}
        </svg>
    );
}
