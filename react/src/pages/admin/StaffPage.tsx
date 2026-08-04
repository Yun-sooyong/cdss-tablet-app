// 15 회원 관리 >> 관리 콘솔 · 구성원
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { UserMinus } from 'lucide-react';
import { toast } from 'sonner';

import { deactivateStaff, getMe, getStaff } from '@/api';
import { qk } from '@/api/keys';
import { ICON_BUTTON } from '@/components/form';
import { ListCount } from '@/components/ListCount';
import { Failed, Pending } from '@/components/QueryState';
import { formatDate } from '@/lib/format';
import { ROLE_LABEL } from '@/lib/staff';
import { cn } from '@/lib/utils';

const GRID =
    'grid grid-cols-[minmax(6rem,1fr)_minmax(9rem,1.5fr)_4rem_minmax(5rem,1fr)_5.5rem_2rem] items-center gap-x-4';

export default function AdminStaffPage() {
    const queryClient = useQueryClient();

    // me가 오기 전엔 본인 행을 못 가리므로 퇴사 버튼을 전부 잠근다
    const { data: me, isPending: mePending } = useQuery({ queryKey: qk.me, queryFn: getMe });
    const members = useQuery({ queryKey: qk.staff, queryFn: getStaff });

    const deactivate = useMutation({
        mutationFn: (id : string) => deactivateStaff(id),
        onSuccess: (staff) => {
            void queryClient.invalidateQueries({ queryKey: qk.staff });
            toast(`${staff.username}을(를) 퇴사 처리했습니다`);
        },
        onError: (error) => {
            toast('퇴사 처리하지 못했습니다', { description: error.message });
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

            <div
                className={cn(
                    GRID,
                    'mb-1.5 border-b border-border pb-1.5 text-xs text-ink-muted',
                )}
            >
                <span>아이디</span>
                <span>이메일</span>
                <span>직군</span>
                <span>소속</span>
                <span className="text-right">가입일</span>
                <span />
            </div>

            <div className="divide-y divide-border">
                {members.data.map((member) => {
                    const self = member.id === me?.id;

                    return (
                        <div key={member.id} className={cn(GRID, 'py-3.5')}>
                            <span className="truncate text-[15px]">
                                {member.username}
                                {self && <span className="ml-1.5 text-xs text-ink-faint">나</span>}
                            </span>

                            <span className="truncate text-sm text-ink-muted" title={member.email}>
                                {member.email}
                            </span>

                            <span className="text-sm text-ink-muted">
                                {ROLE_LABEL[member.role]}
                            </span>

                            <span className="truncate text-sm text-ink-muted">
                                {member.department || '미지정'}
                            </span>

                            <span className="text-right text-sm text-ink-muted">
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

            <p className="mt-4 text-xs text-ink-faint">
                재직 중인 계정만 표시됩니다
            </p>
        </div>
    );
}
