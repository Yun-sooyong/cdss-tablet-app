/* 목록 위 건수 >> 표 위에 같은 자리 같은 크기로 */
export function ListCount({
    value,
    unit,
    prefix,
} : {
    // undefined면 아직 모른다. 0과 구분한다
    value? : number;
    unit : string;
    prefix? : string;
}) {
    return (
        <p className="mb-3 text-sm text-ink-muted">
            {value === undefined ? ' ' : `${prefix ? `${prefix} ` : ''}${value}${unit}`}
        </p>
    );
}
