// 16 내 정보
import { useState } from 'react';
import type { ReactNode } from 'react';
import { useNavigate } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { LogOut } from 'lucide-react';
import { toast } from 'sonner';

import { changePassword, getDepartments, getMe, logout, updateMe } from '@/api';
import { qk } from '@/api/keys';
import { BUTTON_PRIMARY, BUTTON_SECONDARY, FIELD_INPUT } from '@/components/form';
import { PasswordField } from '@/components/PasswordField';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { Badge } from '@/components/ui/badge';
import { formatDate } from '@/lib/format';
import { EMPLOYMENT_LABEL, ROLE_LABEL } from '@/lib/staff';

export default function ProfilePage() {
    const navigate = useNavigate();
    const queryClient = useQueryClient();

    const me = useQuery({ queryKey: qk.me, queryFn: getMe });
    const { data: departments } = useQuery({
        queryKey: qk.departments,
        queryFn: getDepartments,
    });

    // undefined >> 미선택. 서버 값이 기본
    const [picked, setPicked] = useState<string | undefined>(undefined);

    const save = useMutation({
        mutationFn: (department : string) => updateMe({ department }),
        onSuccess: () => {
            void queryClient.invalidateQueries({ queryKey: qk.me });
            void queryClient.invalidateQueries({ queryKey: qk.staff });
            setPicked(undefined);
            toast.success('소속을 변경했습니다');
        },
        onError: (error) => toast.error('변경하지 못했습니다', { description: error.message }),
    });

    async function signOut() {
        await logout();
        queryClient.clear();
        navigate('/login', { replace: true });
    }

    if (me.isPending) return <Pending />;
    if (me.isError) return <Failed error={me.error} onRetry={() => void me.refetch()} />;

    if (!me.data) {
        return (
            <Empty label="로그인 정보를 찾을 수 없습니다." />
        );
    }

    const staff = me.data;
    const department = picked ?? staff.department;
    const dirty = department !== staff.department;

    return (
        <div className="max-w-xl">
            <dl className="divide-y divide-border border-y border-border">
                <Row label="아이디">{staff.username}</Row>
                <Row label="이메일">{staff.email}</Row>
                <Row label="직군">{ROLE_LABEL[staff.role]}</Row>
                <Row label="재직 상태">
                    <Badge variant="outline" className="text-sm font-medium">
                        {EMPLOYMENT_LABEL[staff.employment_status]}
                    </Badge>
                </Row>
                <Row label="가입일">{formatDate(staff.created_at)}</Row>
            </dl>

            <section className="mt-8">
                <h2 className="mb-3 text-base font-medium">소속</h2>

                <select
                    value={department}
                    onChange={(e) => setPicked(e.target.value)}
                    aria-label="소속 부서"
                    className={FIELD_INPUT}
                >
                    {/* 부서 목록에 없는 현재 소속 */}
                    {!(departments ?? []).some((d) => d.name === staff.department) && (
                        <option value={staff.department}>
                            {staff.department || '소속 미지정'}
                        </option>
                    )}
                    {(departments ?? []).map((d) => (
                        <option key={d.dept_code} value={d.name}>
                            {d.name} (내선 {d.extension})
                        </option>
                    ))}
                </select>

                <p className="mt-2 text-xs text-ink-faint">
                    직군 변경은 관리자에게 문의하세요
                </p>

                <button
                    type="button"
                    onClick={() => save.mutate(department)}
                    disabled={!dirty || save.isPending}
                    className={`mt-4 ${BUTTON_PRIMARY}`}
                >
                    저장
                </button>
            </section>

            <PasswordSection />

            <section className="mt-10 border-t border-border pt-6">
                <button
                    type="button"
                    onClick={signOut}
                    className={`${BUTTON_SECONDARY} inline-flex items-center gap-1.5 text-ink-muted hover:border-danger hover:bg-transparent hover:text-danger`}
                >
                    <LogOut size={16} />
                    로그아웃
                </button>
            </section>
        </div>
    );
}

const MIN_PASSWORD = 8;

function PasswordSection() {
    const [oldPassword, setOldPassword] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [error, setError] = useState('');

    const short = !!newPassword && newPassword.length < MIN_PASSWORD;
    const canSubmit = !!oldPassword && !!newPassword && !short;

    const change = useMutation({
        mutationFn: () =>
            changePassword({ old_password: oldPassword, new_password: newPassword }),
        onSuccess: () => {
            setOldPassword('');
            setNewPassword('');
            setError('');
            toast.success('비밀번호를 변경했습니다');
        },
        onError: (err : Error) => setError(err.message || '변경하지 못했습니다.'),
    });

    return (
        <section className="mt-10">
            <h2 className="mb-3 text-base font-medium">비밀번호</h2>

            <div className="space-y-3">
                <PasswordField
                    label="현재 비밀번호"
                    value={oldPassword}
                    onChange={(next) => {
                        setOldPassword(next);
                        setError('');
                    }}
                    autoComplete="current-password"
                />

                <PasswordField
                    label="새 비밀번호"
                    hint={`${MIN_PASSWORD}자 이상`}
                    value={newPassword}
                    onChange={(next) => {
                        setNewPassword(next);
                        setError('');
                    }}
                    autoComplete="new-password"
                />
            </div>

            {(error || short) && (
                <p role="alert" className="mt-3 text-sm text-danger">
                    {error || `새 비밀번호는 ${MIN_PASSWORD}자 이상이어야 합니다.`}
                </p>
            )}

            <button
                type="button"
                onClick={() => change.mutate()}
                disabled={!canSubmit || change.isPending}
                className={`mt-4 ${BUTTON_SECONDARY}`}
            >
                변경
            </button>
        </section>
    );
}

function Row({ label, children } : { label : string; children : ReactNode }) {
    return (
        <div className="flex items-center justify-between gap-4 py-3.5">
            <dt className="shrink-0 text-sm text-ink-muted">{label}</dt>
            <dd className="min-w-0 truncate text-[15px]">{children}</dd>
        </div>
    );
}
