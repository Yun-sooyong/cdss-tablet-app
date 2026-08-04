// 목록용 >> 월일 시분
export const formatShort = (iso : string) : string =>
    new Date(iso).toLocaleString('ko-KR', {
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
    });

export const formatDate = (iso : string) : string =>
    new Date(iso).toLocaleDateString('ko-KR');

const MINUTE = 60_000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;

export const formatRelative = (iso : string) : string => {
    const diff = Date.now() - new Date(iso).getTime();

    if (diff < MINUTE) return '방금';
    if (diff < HOUR) return `${Math.floor(diff / MINUTE)}분 전`;
    if (diff < DAY) return `${Math.floor(diff / HOUR)}시간 전`;
    if (diff < 7 * DAY) return `${Math.floor(diff / DAY)}일 전`;

    return formatDate(iso);
};
