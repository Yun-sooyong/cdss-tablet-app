// 17 초대코드 가입
import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { toast } from 'sonner';

import { redeemInvitation } from '@/api';
import { PasswordField } from '@/components/PasswordField';
import AuthShell, { FIELD_INPUT, FIELD_SUBMIT, Field } from '@/components/layout/AuthShell';

const MIN_PASSWORD = 8;

export default function SignUpPage() {
    const navigate = useNavigate();

    const [code, setCode] = useState('');
    const [username, setUsername] = useState('');
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');

    const shortPassword = !!password && password.length < MIN_PASSWORD;
    const canSubmit =
        !!code.trim() && !!username.trim() && !!email.trim() && !shortPassword && !!password;

    const redeem = useMutation({
        mutationFn: () =>
            redeemInvitation({
                code: code.trim(),
                username: username.trim(),
                email: email.trim(),
                password,
            }),
        onSuccess: () => {
            toast.success('가입이 완료되었습니다', { description: '새 계정으로 로그인해 주세요.' });
            navigate('/login', { replace: true });
        },
        onError: (err : Error) => setError(err.message || '가입에 실패했습니다.'),
    });

    function submit(e : FormEvent) {
        e.preventDefault();
        if (!canSubmit || redeem.isPending) return;

        redeem.mutate();
    }

    return (
        <AuthShell
            title="초대코드 가입"
            description="발급받은 초대코드를 입력하세요"
            footer={
                <>
                    이미 계정이 있으신가요?{' '}
                    <Link to="/login" className="text-ink underline-offset-2 hover:underline">
                        로그인
                    </Link>
                </>
            }
        >
            <form onSubmit={submit} className="space-y-4">
                <Field label="초대코드">
                    <input
                        value={code}
                        onChange={(e) => {
                            setCode(e.target.value.toUpperCase());
                            setError('');
                        }}
                        maxLength={12}
                        placeholder="K7M2QX9A"
                        className={`${FIELD_INPUT} font-mono tracking-widest`}
                    />
                </Field>

                <Field label="아이디">
                    <input
                        value={username}
                        onChange={(e) => {
                            setUsername(e.target.value);
                            setError('');
                        }}
                        maxLength={150}
                        autoComplete="username"
                        className={FIELD_INPUT}
                    />
                </Field>

                <Field label="이메일">
                    <input
                        type="email"
                        value={email}
                        onChange={(e) => {
                            setEmail(e.target.value);
                            setError('');
                        }}
                        autoComplete="email"
                        className={FIELD_INPUT}
                    />
                </Field>

                <PasswordField
                    label="비밀번호"
                    hint={`${MIN_PASSWORD}자 이상`}
                    value={password}
                    onChange={(next) => {
                        setPassword(next);
                        setError('');
                    }}
                    autoComplete="new-password"
                />

                {(error || shortPassword) && (
                    <p role="alert" className="text-sm text-danger">
                        {error || `비밀번호는 ${MIN_PASSWORD}자 이상이어야 합니다.`}
                    </p>
                )}

                <button type="submit" disabled={!canSubmit} className={FIELD_SUBMIT}>
                    가입
                </button>
            </form>
        </AuthShell>
    );
}
