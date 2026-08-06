// 관리 콘솔 · 계정 요청 >> 승인하면 서버가 계정을 만들고 임시 비밀번호를 1회 돌려준다
import { useState } from 'react';
import { useSearchParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, Copy, X } from 'lucide-react';
import { toast } from 'sonner';

import {
    approveAccountRequest,
    getAccountRequests,
    getDepartments,
    getStaff,
    rejectAccountRequest,
} from '@/api';
import { qk } from '@/api/keys';
import type {
    AccountRequest,
    AccountRequestApproved,
    AccountRequestStatus,
    Role,
} from '@/api/types';
import { BUTTON_PRIMARY, BUTTON_QUIET, FIELD_INPUT } from '@/components/form';
import { ListCount } from '@/components/ListCount';
import { Failed, Pending } from '@/components/QueryState';
import { StateBadge } from '@/components/StateBadge';
import { formatShort } from '@/lib/format';
import { REQUEST_STATUS_LABEL, ROLE_LABEL } from '@/lib/staff';
import { cn } from '@/lib/utils';

const GRID =
    'grid min-w-[46rem] grid-cols-[minmax(6rem,1fr)_minmax(9rem,1.4fr)_4rem_minmax(5rem,1fr)_4rem_6rem_7rem] items-center gap-x-4';

const ROLE_OPTIONS : Role[] = ['doctor', 'nurse', 'admin'];

const STATUS_TABS : AccountRequestStatus[] = ['pending', 'approved', 'rejected'];

export default function AdminAccountRequestsPage() {
    const queryClient = useQueryClient();
    const [searchParams, setSearchParams] = useSearchParams();

    const status = (searchParams.get('status') ?? 'pending') as AccountRequestStatus;

    const requests = useQuery({
        queryKey: qk.accountRequests(status),
        queryFn: () => getAccountRequests(status),
    });

    // 승인자는 staff id로 오므로 아이디를 붙이려면 구성원 목록이 필요하다
    const { data: staff } = useQuery({ queryKey: qk.staff, queryFn: getStaff });
    const staffById = new Map((staff ?? []).map((s) => [s.id, s]));

    function setStatus(next : AccountRequestStatus) {
        const params = new URLSearchParams(searchParams);
        params.set('status', next);
        setSearchParams(params, { replace: true });
    }

    // 승인 응답을 붙들어 둔다. 닫으면 임시 비밀번호를 다시 볼 수 없다
    const [issued, setIssued] = useState<AccountRequestApproved | null>(null);

    return (
        <div>
            {issued && <IssuedPanel issued={issued} onClose={() => setIssued(null)} />}

            <div className="mb-4 flex items-center gap-0.5 rounded-md border border-border p-0.5 w-fit">
                {STATUS_TABS.map((tab) => (
                    <button
                        key={tab}
                        type="button"
                        onClick={() => setStatus(tab)}
                        aria-pressed={status === tab}
                        className={cn(
                            'flex h-8 items-center rounded px-3 text-sm transition-colors',
                            status === tab
                                ? 'bg-surface-raised font-medium text-ink shadow-sm'
                                : 'text-ink-muted hover:bg-ink/[0.04] hover:text-ink',
                        )}
                    >
                        {REQUEST_STATUS_LABEL[tab]}
                    </button>
                ))}
            </div>

            <ListCount
                value={requests.data?.length}
                unit="건"
                prefix={REQUEST_STATUS_LABEL[status]}
            />

            <div
                className={cn(
                    GRID,
                    'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted',
                )}
            >
                <span>이름</span>
                <span>이메일</span>
                <span>직군</span>
                <span>소속</span>
                <span>상태</span>
                <span className="text-right">요청</span>
                <span className="text-right">
                    {status === 'pending' ? '' : '처리'}
                </span>
            </div>

            {requests.isPending ? (
                <Pending />
            ) : requests.isError ? (
                <Failed error={requests.error} onRetry={() => void requests.refetch()} />
            ) : requests.data.length === 0 ? (
                <div className="py-16 text-center text-sm text-ink-faint">
                    {REQUEST_STATUS_LABEL[status]} 상태인 요청이 없습니다
                </div>
            ) : (
                <div className="divide-y divide-border">
                    {requests.data.map((request) => (
                        <RequestRow
                            key={request.id}
                            request={request}
                            reviewer={
                                request.reviewed_by
                                    ? staffById.get(request.reviewed_by)?.username
                                    : undefined
                            }
                            onIssued={(next) => {
                                setIssued(next);
                                void queryClient.invalidateQueries({
                                    queryKey: qk.accountRequests(status),
                                });
                                void queryClient.invalidateQueries({ queryKey: qk.staff });
                            }}
                            onRejected={() =>
                                void queryClient.invalidateQueries({
                                    queryKey: qk.accountRequests(status),
                                })
                            }
                        />
                    ))}
                </div>
            )}

            <p className="mt-4 text-xs text-ink-faint">
                승인하면 계정이 만들어집니다. 임시 비밀번호는 그때 한 번만 표시됩니다
            </p>
        </div>
    );
}

function RequestRow({
    request,
    reviewer,
    onIssued,
    onRejected,
} : {
    request : AccountRequest;
    reviewer? : string;
    onIssued : (issued : AccountRequestApproved) => void;
    onRejected : () => void;
}) {
    const { data: departments } = useQuery({
        queryKey: qk.departments,
        queryFn: getDepartments,
    });

    const [open, setOpen] = useState(false);
    const [username, setUsername] = useState('');
    const [role, setRole] = useState<Role>(request.role);
    const [department, setDepartment] = useState(request.department);

    const approve = useMutation({
        mutationFn: () =>
            approveAccountRequest(request.id, {
                username: username.trim(),
                role,
                department: department || undefined,
            }),
        onSuccess: (issued) => {
            setOpen(false);
            onIssued(issued);
        },
        onError: (error : Error) =>
            toast('승인하지 못했습니다', { description: error.message }),
    });

    const reject = useMutation({
        mutationFn: () => rejectAccountRequest(request.id),
        onSuccess: () => {
            onRejected();
            toast(`${request.name} 요청을 거절했습니다`);
        },
        onError: (error : Error) =>
            toast('거절하지 못했습니다', { description: error.message }),
    });

    function confirmReject() {
        if (!window.confirm(`${request.name}의 계정 요청을 거절합니다.`)) return;
        reject.mutate();
    }

    return (
        <div className="py-3.5">
            <div className={GRID}>
                <span className="truncate text-base">{request.name}</span>

                <span className="truncate text-sm text-ink-muted" title={request.email}>
                    {request.email}
                </span>

                <span className="text-sm text-ink-muted">{ROLE_LABEL[request.role]}</span>

                <span className="truncate text-sm text-ink-muted">
                    {request.department || '미지정'}
                </span>

                <span>
                    <StateBadge
                        label={REQUEST_STATUS_LABEL[request.status]}
                        live={request.status === 'pending'}
                    />
                </span>

                <span className="truncate text-right text-sm text-ink-muted">
                    {formatShort(request.created_at)}
                </span>

                {request.status !== 'pending' ? (
                    // 처리된 요청은 이력이다. 누가 언제 처리했는지만 남긴다
                    <span className="truncate text-right text-xs text-ink-faint">
                        {request.reviewed_at ? formatShort(request.reviewed_at) : '-'}
                        {reviewer && <span className="block truncate">{reviewer}</span>}
                    </span>
                ) : (
                <span className="flex justify-end gap-1.5">
                    <button
                        type="button"
                        onClick={() => setOpen((prev) => !prev)}
                        aria-expanded={open}
                        className={BUTTON_QUIET}
                    >
                        <Check size={12} />
                        승인
                    </button>

                    <button
                        type="button"
                        onClick={confirmReject}
                        disabled={reject.isPending}
                        className={`${BUTTON_QUIET} hover:text-danger`}
                    >
                        <X size={12} />
                        거절
                    </button>
                </span>
                )}
            </div>

            {/* 아이디는 관리자가 정한다. 직군·소속은 요청값을 기본으로 두되 고칠 수 있다 */}
            {open && (
                <div className="mt-3 flex flex-wrap items-end gap-3 rounded-lg border border-border p-4">
                    <label className="block">
                        <span className="mb-1.5 block text-xs text-ink-muted">아이디</span>
                        <input
                            value={username}
                            onChange={(e) => setUsername(e.target.value)}
                            placeholder="doctor_kim"
                            className={`${FIELD_INPUT} w-48`}
                        />
                    </label>

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

                    <button
                        type="button"
                        onClick={() => approve.mutate()}
                        disabled={!username.trim() || approve.isPending}
                        className={BUTTON_PRIMARY}
                    >
                        계정 만들기
                    </button>

                    {request.note && (
                        <p className="w-full text-xs text-ink-faint">사유 — {request.note}</p>
                    )}
                </div>
            )}
        </div>
    );
}

// 임시 비밀번호는 이 응답에만 있다. 닫기 전에 반드시 옮겨 적어야 한다
function IssuedPanel({
    issued,
    onClose,
} : {
    issued : AccountRequestApproved;
    onClose : () => void;
}) {
    const text = `아이디: ${issued.username}\n임시 비밀번호: ${issued.temporary_password}`;

    async function copyAll() {
        try {
            await navigator.clipboard.writeText(text);
            toast('복사했습니다');
        } catch {
            toast('복사하지 못했습니다');
        }
    }

    return (
        <div
            role="alert"
            className="mb-6 rounded-lg border border-decision-abstain/60 bg-decision-abstain/10 p-4"
        >
            <p className="text-sm font-medium text-ink">
                계정을 만들었습니다. 임시 비밀번호는 지금만 볼 수 있습니다
            </p>

            <dl className="mt-3 grid grid-cols-[5rem_1fr] gap-y-1.5 font-mono text-sm">
                <dt className="text-ink-muted">아이디</dt>
                <dd className="text-ink">{issued.username}</dd>
                <dt className="text-ink-muted">비밀번호</dt>
                <dd className="text-ink">{issued.temporary_password}</dd>
            </dl>

            <div className="mt-4 flex gap-2">
                <button type="button" onClick={() => void copyAll()} className={BUTTON_QUIET}>
                    <Copy size={12} />
                    복사
                </button>

                <button type="button" onClick={onClose} className={BUTTON_QUIET}>
                    옮겨 적었습니다
                </button>
            </div>
        </div>
    );
}
