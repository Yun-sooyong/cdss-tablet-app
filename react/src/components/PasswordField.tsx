import { useId, useState } from 'react';
import { Eye, EyeOff } from 'lucide-react';

import { FIELD_INPUT, ICON_BUTTON } from '@/components/form';

/* 비밀번호 입력 >> 보기 토글 포함. 힌트·오류는 aria-describedby로 묶는다 */
export function PasswordField({
    label,
    value,
    onChange,
    autoComplete,
    hint,
} : {
    label : string;
    value : string;
    onChange : (value : string) => void;
    autoComplete : 'current-password' | 'new-password';
    hint? : string;
}) {
    const [shown, setShown] = useState(false);
    const hintId = useId();

    return (
        <label className="block">
            <span className="mb-1.5 block text-sm text-ink-muted">{label}</span>

            <span className="relative block">
                <input
                    type={shown ? 'text' : 'password'}
                    value={value}
                    onChange={(e) => onChange(e.target.value)}
                    autoComplete={autoComplete}
                    aria-describedby={hint ? hintId : undefined}
                    className={`${FIELD_INPUT} pr-10`}
                />

                <button
                    type="button"
                    onClick={() => setShown((prev) => !prev)}
                    aria-label={shown ? '비밀번호 숨기기' : '비밀번호 표시'}
                    aria-pressed={shown}
                    className={`absolute right-2.5 top-1/2 -translate-y-1/2 ${ICON_BUTTON}`}
                >
                    {shown ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
            </span>

            {hint && (
                <span id={hintId} className="mt-1.5 block text-xs text-ink-faint">
                    {hint}
                </span>
            )}
        </label>
    );
}
