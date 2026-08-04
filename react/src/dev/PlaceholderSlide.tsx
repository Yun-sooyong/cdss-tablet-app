// H&E 염색 병리 이미지를 흉내낸 SVG. 확대해도 선명해서 줌 동작 확인에 쓴다.
export function PlaceholderSlide({ className }: { className?: string }) {
    const cells = Array.from({ length: 220 }, (_, i) => {
        const x = (i * 37) % 100;
        const y = (i * 61) % 100;
        const r = 0.6 + ((i * 13) % 7) / 10;
        const purple = (i * 7) % 3 === 0;
        return { x, y, r, purple };
    });

    return (
        <svg viewBox="0 0 100 100" className={className} preserveAspectRatio="none">
            <rect width="100" height="100" fill="#f0dfe6" />

            {Array.from({ length: 14 }, (_, i) => (
                <path
                    key={`stroma-${i}`}
                    d={`M ${i * 8 - 6} 100 Q ${i * 8 + 12} 50 ${i * 8 + 2} 0`}
                    stroke="#e0b9c8"
                    strokeWidth="3.5"
                    fill="none"
                />
            ))}

            {cells.map((c, i) => (
                <circle
                    key={i}
                    cx={c.x}
                    cy={c.y}
                    r={c.r}
                    fill={c.purple ? '#6b3a68' : '#a86b8c'}
                    opacity={0.75}
                />
            ))}
        </svg>
    );
}
