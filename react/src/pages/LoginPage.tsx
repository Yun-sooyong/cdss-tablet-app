// 01 로그인
import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation, useQueryClient } from '@tanstack/react-query';

import { getMe, login } from '@/api';
import { PasswordField } from '@/components/PasswordField';
import AuthShell, { FIELD_INPUT, FIELD_SUBMIT, Field } from '@/components/layout/AuthShell';

export default function LoginPage() {
    const navigate = useNavigate();
    const queryClient = useQueryClient();

    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');

    const canSubmit = !!username.trim() && !!password;

    const signIn = useMutation({
        mutationFn: async () => {
            await login(username.trim(), password);
            return getMe();
        },
        // 관리자 → 관리 콘솔, 그 외 → 판독 콘솔
        onSuccess: (me) => {
            queryClient.clear();
            navigate(me?.role === 'admin' ? '/admin' : '/', { replace: true });
        },
        onError: (err : Error) => setError(err.message || '로그인에 실패했습니다.'),
    });

    function submit(e : FormEvent) {
        e.preventDefault();
        if (!canSubmit || signIn.isPending) return;

        signIn.mutate();
    }

    return (
        <AuthShell
            title="로그인"
            description="sTIL 판독 콘솔"
            footer={
                <>
                    초대코드를 받으셨나요?{' '}
                    <Link to="/signup" className="text-ink underline-offset-2 hover:underline">
                        가입하기
                    </Link>
                </>
            }
        >
            <form onSubmit={submit} className="space-y-4">
                <Field label="아이디">
                    <input
                        value={username}
                        onChange={(e) => {
                            setUsername(e.target.value);
                            setError('');
                        }}
                        autoComplete="username"
                        className={FIELD_INPUT}
                    />
                </Field>

                <PasswordField
                    label="비밀번호"
                    value={password}
                    onChange={(next) => {
                        setPassword(next);
                        setError('');
                    }}
                    autoComplete="current-password"
                />

                {error && (
                    <p role="alert" className="text-sm text-danger">
                        {error}
                    </p>
                )}

                <button
                    type="submit"
                    disabled={!canSubmit || signIn.isPending}
                    className={FIELD_SUBMIT}
                >
                    {signIn.isPending ? '확인 중…' : '로그인'}
                </button>
            </form>
        </AuthShell>
    );
}
