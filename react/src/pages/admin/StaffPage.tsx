// 15 회원 관리 >> 관리 콘솔 · 구성원
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { UserMinus } from 'lucide-react';
import { toast } from 'sonner';

import { deactivateStaff, getDepartments, getMe, getStaff, updateStaff } from '@/api';
import { qk } from '@/api/keys';
import type { Role } from '@/api/types';
import { FIELD_INPUT, ICON_BUTTON } from '@/components/form';
import { ListCount } from '@/components/ListCount';
import { ListFrame } from '@/components/ListFrame';
import { Failed, Pending } from '@/components/QueryState';
import { formatDate } from '@/lib/format';
import { ROLE_LABEL } from '@/lib/staff';
import { cn } from '@/lib/utils';

const GRID =
    'grid min-w-[46rem] grid-cols-[minmax(6rem,1fr)_minmax(9rem,1.5fr)_6rem_minmax(7rem,1fr)_5.5rem_2rem] items-center gap-x-4';

// 표 안에서 쓰는 낮은 높이의 선택 상자
const ROW_SELECT = `${FIELD_INPUT} h-8 px-2 text-sm disabled:opacity-50`;

export default function AdminStaffPage() {
    const queryClient = useQueryClient();

    // me가 오기 전엔 본인 행을 못 가리므로 퇴사 버튼을 전부 잠근다
    const { data: me, isPending: mePending } = useQuery({ queryKey: qk.me, queryFn: getMe });
    const members = useQuery({ queryKey: qk.staff, queryFn: getStaff });

    const { data: departments } = useQuery({
        queryKey: qk.departments,
        queryFn: getDepartments,
    });

    // 본인 직군은 서버가 막지 않는다. 권한을 스스로 내리면 되돌릴 사람이 없어진다
    const change = useMutation({
        mutationFn: ({ id, body } : { id : string; body : { role? : Role; department? : string } }) =>
            updateStaff(id, body),
        onSuccess: (staff) => {
            void queryClient.invalidateQueries({ queryKey: qk.staff });
            toast.success(`${staff.username} 정보를 바꿨습니다`);
        },
        onError: (error : Error) =>
            toast.error('바꾸지 못했습니다', { description: error.message }),
    });

    const deactivate = useMutation({
        mutationFn: (id : string) => deactivateStaff(id),
        onSuccess: (staff) => {
            void queryClient.invalidateQueries({ queryKey: qk.staff });
            toast.success(`${staff.username}을(를) 퇴사 처리했습니다`);
        },
        onError: (error) => {
            toast.error('퇴사 처리하지 못했습니다', { description: error.message });
        },
    });

    function confirmDeactivate(id : string, username : string) {
        if (!window.confirm(`${username}을(를) 퇴사 처리합니다. 계정으로 로그인할 수 없게 됩니다.`))
            return;

        deactivate.mutate(id);
    }

    if (members.isPending) return <Pending />;
    if (members.isError) {
        return <Failed error={members.error} onRetry={() => void members.refetch()} />;
    }

    return (
        <div>
            <ListCount prefix="재직" value={members.data.length} unit="명" />

            <ListFrame
                grid={GRID}
                header={
                    <>
                        <span>아이디</span>
                        <span>이메일</span>
                        <span>직군</span>
                        <span>소속</span>
                        <span className="text-right">가입일</span>
                        <span />
                    </>
                }
            >
                <div className="divide-y divide-border">
                    {members.data.map((member) => {
                        const self = member.id === me?.id;

                        return (
                            <div key={member.id} className={cn(GRID, 'py-3.5')}>
                                <span className="truncate text-base">
                                    {member.username}
                                    {self && <span className="ml-1.5 text-xs text-ink-faint">나</span>}
                                </span>

                                <span className="truncate text-sm text-ink-muted" title={member.email}>
                                    {member.email}
                                </span>

                                {/* 본인 직군을 내리면 되돌릴 관리자가 없어질 수 있다 */}
                                <select
                                    value={member.role}
                                    onChange={(e) =>
                                        change.mutate({
                                            id: member.id,
                                            body: { role: e.target.value as Role },
                                        })
                                    }
                                    disabled={self || change.isPending}
                                    aria-label={`${member.username} 직군`}
                                    title={self ? '본인 직군은 바꿀 수 없습니다' : undefined}
                                    className={ROW_SELECT}
                                >
                                    {(Object.entries(ROLE_LABEL) as [Role, string][]).map(
                                        ([value, label]) => (
                                            <option key={value} value={value}>
                                                {label}
                                            </option>
                                        ),
                                    )}
                                </select>

                                <select
                                    value={member.department || ''}
                                    onChange={(e) =>
                                        change.mutate({
                                            id: member.id,
                                            body: { department: e.target.value },
                                        })
                                    }
                                    disabled={change.isPending}
                                    aria-label={`${member.username} 소속`}
                                    className={ROW_SELECT}
                                >
                                    <option value="">미지정</option>
                                    {(departments ?? []).map((d) => (
                                        <option key={d.dept_code} value={d.name}>
                                            {d.name}
                                        </option>
                                    ))}
                                </select>

                                <span className="truncate text-right text-sm text-ink-muted">
                                    {formatDate(member.created_at)}
                                </span>

                                {/* 본인 제외 */}
                                <button
                                    type="button"
                                    onClick={() => confirmDeactivate(member.id, member.username)}
                                    disabled={self || mePending || deactivate.isPending}
                                    aria-label={`${member.username} 퇴사 처리`}
                                    title={self ? '본인은 퇴사 처리할 수 없습니다' : '퇴사 처리'}
                                    className={`justify-self-end hover:text-danger ${ICON_BUTTON}`}
                                >
                                    <UserMinus size={15} />
                                </button>
                            </div>
                        );
                    })}
                </div>
            </ListFrame>

            <p className="mt-4 text-xs text-ink-faint">
                재직 중인 계정만 표시됩니다
            </p>
        </div>
    );
}
