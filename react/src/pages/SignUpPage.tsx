// 계정 요청 >> 관리자가 승인하면 아이디와 임시 비밀번호를 메일로 받는다
import { useState } from 'react';
import type { FormEvent } from 'react';
import { Link } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';

import { createAccountRequest, getDepartments } from '@/api';
import { qk } from '@/api/keys';
import type { Role } from '@/api/types';
import AuthShell, { FIELD_INPUT, FIELD_SUBMIT, Field } from '@/components/layout/AuthShell';
import { ROLE_LABEL } from '@/lib/staff';
import { useQuery } from '@tanstack/react-query';

const ROLE_OPTIONS : Role[] = ['doctor', 'nurse', 'admin'];

export default function SignUpPage() {
    const { data: departments } = useQuery({
        queryKey: qk.departments,
        queryFn: getDepartments,
    });

    const [name, setName] = useState('');
    const [email, setEmail] = useState('');
    const [role, setRole] = useState<Role>('doctor');
    const [department, setDepartment] = useState('');
    const [note, setNote] = useState('');
    const [error, setError] = useState('');

    const canSubmit = !!name.trim() && !!email.trim();

    const request = useMutation({
        mutationFn: () =>
            createAccountRequest({
                name: name.trim(),
                email: email.trim(),
                role,
                department: department || undefined,
                note: note.trim() || undefined,
            }),
        onError: (err : Error) => setError(err.message || '요청을 보내지 못했습니다.'),
    });

    function submit(e : FormEvent) {
        e.preventDefault();
        if (!canSubmit || request.isPending) return;

        setError('');
        request.mutate();
    }

    if (request.isSuccess) {
        return (
            <AuthShell
                title="요청을 접수했습니다"
                description="관리자가 확인한 뒤 계정 정보를 메일로 보냅니다."
                footer={
                    <Link to="/login" className="text-ink underline-offset-2 hover:underline">
                        로그인으로
                    </Link>
                }
            >
                <p className="rounded-md border border-border bg-surface px-4 py-3 text-sm text-ink-muted">
                    {email.trim()}
                </p>
            </AuthShell>
        );
    }

    return (
        <AuthShell
            title="계정 요청"
            description="관리자 승인 후 계정 정보를 메일로 받습니다."
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
                <Field label="이름">
                    <input
                        value={name}
                        onChange={(e) => {
                            setName(e.target.value);
                            setError('');
                        }}
                        maxLength={100}
                        autoComplete="name"
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
                    <span className="mt-1.5 block text-xs text-ink-faint">
                        이 주소로 계정 정보를 보냅니다
                    </span>
                </Field>

                <Field label="직군">
                    <select
                        value={role}
                        onChange={(e) => setRole(e.target.value as Role)}
                        className={FIELD_INPUT}
                    >
                        {ROLE_OPTIONS.map((r) => (
                            <option key={r} value={r}>
                                {ROLE_LABEL[r]}
                            </option>
                        ))}
                    </select>
                </Field>

                <Field label="소속">
                    <select
                        value={department}
                        onChange={(e) => setDepartment(e.target.value)}
                        className={FIELD_INPUT}
                    >
                        <option value="">미지정</option>
                        {(departments ?? []).map((d) => (
                            <option key={d.dept_code} value={d.name}>
                                {d.name}
                            </option>
                        ))}
                    </select>
                </Field>

                <Field label="요청 사유">
                    <textarea
                        value={note}
                        onChange={(e) => setNote(e.target.value)}
                        rows={3}
                        className={`${FIELD_INPUT} h-auto py-2`}
                    />
                </Field>

                {error && (
                    <p role="alert" className="text-sm text-danger">
                        {error}
                    </p>
                )}

                <button type="submit" disabled={!canSubmit || request.isPending} className={FIELD_SUBMIT}>
                    {request.isPending ? '보내는 중' : '요청 보내기'}
                </button>
            </form>
        </AuthShell>
    );
}
