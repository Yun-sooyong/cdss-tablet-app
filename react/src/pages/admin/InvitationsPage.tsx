// 관리 콘솔 · 초대코드 발급 (가입 화면은 17 초대코드 가입)
import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Copy } from 'lucide-react';
import { toast } from 'sonner';

import { getDepartments, getIssuedInvitations, issueInvitation } from '@/api';
import { qk } from '@/api/keys';
import type { Role } from '@/api/types';
import { BUTTON_PRIMARY, FIELD_INPUT, ICON_BUTTON } from '@/components/form';
import { ListCount } from '@/components/ListCount';
import { ListFrame } from '@/components/ListFrame';
import { Empty, Failed, Pending } from '@/components/QueryState';
import { StateBadge } from '@/components/StateBadge';
import { formatDate } from '@/lib/format';
import { INVITATION_STATE_LABEL, ROLE_LABEL, invitationState } from '@/lib/staff';
import { cn } from '@/lib/utils';

const GRID =
    'grid min-w-[36rem] grid-cols-[7rem_4rem_minmax(5rem,1fr)_5.5rem_5rem_2rem] items-center gap-x-4';

const ROLE_OPTIONS : Role[] = ['doctor', 'nurse', 'admin'];

// 서버가 1~30일만 받는다
const EXPIRY_OPTIONS = [3, 7, 14, 30];

async function copyCode(code : string) {
    try {
        await navigator.clipboard.writeText(code);
        toast.info('초대코드를 복사했습니다');
    } catch {
        toast.error('복사하지 못했습니다', { description: code });
    }
}

export default function AdminInvitationsPage() {
    const queryClient = useQueryClient();

    const { data: departments } = useQuery({
        queryKey: qk.departments,
        queryFn: getDepartments,
    });
    const invitations = useQuery({
        queryKey: qk.invitations,
        queryFn: getIssuedInvitations,
    });

    const [role, setRole] = useState<Role>('doctor');
    const [department, setDepartment] = useState('');
    const [days, setDays] = useState(7);

    const issue = useMutation({
        mutationFn: () =>
            issueInvitation({
                role,
                department: department || undefined,
                expires_in_days: days,
            }),
        onSuccess: (invitation) => {
            void queryClient.invalidateQueries({ queryKey: qk.invitations });
            toast.success(`초대코드 ${invitation.code}`, {
                description: `${ROLE_LABEL[invitation.role]} · ${invitation.department || '소속 미지정'} · ${days}일 후 만료`,
                action: { label: '복사', onClick: () => void copyCode(invitation.code) },
            });
        },
        onError: (error) => {
            toast.error('발급하지 못했습니다', { description: error.message });
        },
    });

    return (
        <div>
            <div className="mb-6 flex flex-wrap items-end gap-3 rounded-lg border border-border p-4">
                <label className="block">
                    <span className="mb-1.5 block text-xs text-ink-muted">직군</span>
                    <select
                        value={role}
                        onChange={(e) => setRole(e.target.value as Role)}
                        className={`${FIELD_INPUT} w-auto`}
                    >
                        {ROLE_OPTIONS.map((r) => (
                            <option key={r} value={r}>
                                {ROLE_LABEL[r]}
                            </option>
                        ))}
                    </select>
                </label>

                <label className="block">
                    <span className="mb-1.5 block text-xs text-ink-muted">소속</span>
                    <select
                        value={department}
                        onChange={(e) => setDepartment(e.target.value)}
                        className={`${FIELD_INPUT} w-auto`}
                    >
                        <option value="">미지정</option>
                        {(departments ?? []).map((d) => (
                            <option key={d.dept_code} value={d.name}>
                                {d.name}
                            </option>
                        ))}
                    </select>
                </label>

                <label className="block">
                    <span className="mb-1.5 block text-xs text-ink-muted">유효기간</span>
                    <select
                        value={days}
                        onChange={(e) => setDays(Number(e.target.value))}
                        className={`${FIELD_INPUT} w-auto`}
                    >
                        {EXPIRY_OPTIONS.map((d) => (
                            <option key={d} value={d}>
                                {d}일
                            </option>
                        ))}
                    </select>
                </label>

                <button
                    type="button"
                    onClick={() => issue.mutate()}
                    disabled={issue.isPending}
                    className={BUTTON_PRIMARY}
                >
                    발급
                </button>
            </div>

            <ListCount value={invitations.data?.length} unit="개" />

            <ListFrame
                grid={GRID}
                header={
                    <>
                        <span>코드</span>
                        <span>직군</span>
                        <span>소속</span>
                        <span className="text-right">만료</span>
                        <span>상태</span>
                        <span />
                    </>
                }
            >
                {invitations.isPending ? (
                    <Pending />
                ) : invitations.isError ? (
                    <Failed
                        error={invitations.error}
                        onRetry={() => void invitations.refetch()}
                    />
                ) : invitations.data.length === 0 ? (
                    <Empty label="발급한 초대코드가 없습니다" />
                ) : (
                    <div className="divide-y divide-border">
                        {invitations.data.map((invitation) => {
                            const state = invitationState(invitation);

                            return (
                                <div key={invitation.code} className={cn(GRID, 'py-3.5')}>
                                    <span
                                        className={cn(
                                            'font-mono text-sm tracking-wider',
                                            state === 'live' ? 'text-ink' : 'text-ink-faint',
                                        )}
                                    >
                                        {invitation.code}
                                    </span>

                                    <span className="text-sm text-ink-muted">
                                        {ROLE_LABEL[invitation.role]}
                                    </span>

                                    <span className="truncate text-sm text-ink-muted">
                                        {invitation.department || '미지정'}
                                    </span>

                                    <span className="truncate text-right text-sm text-ink-muted">
                                        {formatDate(invitation.expires_at)}
                                    </span>

                                    <span>
                                        <StateBadge
                                            label={INVITATION_STATE_LABEL[state]}
                                            live={state === 'live'}
                                        />
                                    </span>

                                    {/* 사용 가능한 코드만 복사 */}
                                    <button
                                        type="button"
                                        onClick={() => void copyCode(invitation.code)}
                                        disabled={state !== 'live'}
                                        aria-label={`${invitation.code} 복사`}
                                        className={`justify-self-end ${ICON_BUTTON}`}
                                    >
                                        <Copy size={15} />
                                    </button>
                                </div>
                            );
                        })}
                    </div>
                )}
            </ListFrame>

            <p className="mt-4 text-xs text-ink-faint">
                코드에 직군과 소속이 포함됩니다
            </p>
        </div>
    );
}
