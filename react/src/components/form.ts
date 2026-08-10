/* 폼 프리미티브 >> 입력·버튼 클래스를 여기 한 곳에만 둔다 */

const FOCUS =
    'focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-brand';

// 어두운 배경에서는 입력칸이 바탕과 같은 색으로 묻힌다. 한 단 올리고 테두리를 세운다
export const FIELD_INPUT =
    `h-10 w-full rounded-md border border-border bg-surface px-3 text-[15px] text-ink placeholder:text-ink-faint focus:border-brand focus:outline-none dark:border-border-strong dark:bg-surface-raised ${FOCUS}`;

export const FIELD_SUBMIT =
    `h-10 w-full rounded-md bg-brand text-[15px] font-medium text-on-brand transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40 ${FOCUS}`;

// BUTTON_PRIMARY >> 폭이 내용에 맞는 주 동작
export const BUTTON_PRIMARY =
    `h-10 rounded-md bg-brand px-5 text-[15px] font-medium text-on-brand transition-opacity hover:opacity-90 disabled:cursor-not-allowed disabled:opacity-40 ${FOCUS}`;

export const BUTTON_SECONDARY =
    `h-10 rounded-md border border-border px-4 text-[15px] text-ink transition-colors hover:bg-brand-soft disabled:cursor-not-allowed disabled:opacity-40 ${FOCUS}`;

// BUTTON_QUIET >> 표 안의 작은 동작
export const BUTTON_QUIET =
    `inline-flex items-center gap-1 rounded-md border border-border px-2 py-1 text-xs text-ink-muted transition-colors hover:text-ink disabled:cursor-not-allowed disabled:opacity-40 ${FOCUS}`;

// ICON_BUTTON >> 아이콘만 있는 버튼. aria-label을 반드시 함께 준다
export const ICON_BUTTON =
    `text-ink-faint transition-colors hover:text-ink disabled:cursor-not-allowed disabled:opacity-30 disabled:hover:text-ink-faint ${FOCUS}`;
