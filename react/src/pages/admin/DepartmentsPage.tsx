// 관리 콘솔 · 부서
import { useQuery } from '@tanstack/react-query';

import { getDepartments, getStaff } from '@/api';
import { qk } from '@/api/keys';
import { ListCount } from '@/components/ListCount';
import { ListFrame } from '@/components/ListFrame';
import { Failed, Pending } from '@/components/QueryState';
import { cn } from '@/lib/utils';

const GRID = 'grid min-w-[28rem] grid-cols-[5rem_minmax(7rem,1fr)_5rem_4rem] items-center gap-x-5';

export default function AdminDepartmentsPage() {
    const departments = useQuery({ queryKey: qk.departments, queryFn: getDepartments });
    const members = useQuery({ queryKey: qk.staff, queryFn: getStaff });

    if (departments.isPending) return <Pending />;
    if (departments.isError) {
        return <Failed error={departments.error} onRetry={() => void departments.refetch()} />;
    }

    // 인원 >> 서버가 세어 주지 않아 구성원 목록에서 집계
    const headcount = new Map<string, number>();
    for (const member of members.data ?? []) {
        headcount.set(member.department, (headcount.get(member.department) ?? 0) + 1);
    }

    return (
        <div>
            <ListCount value={departments.data.length} unit="개" />

            <ListFrame
                grid={GRID}
                header={
                    <>
                        <span>코드</span>
                        <span>이름</span>
                        <span className="text-right">내선</span>
                        <span className="text-right">인원</span>
                    </>
                }
            >
                <div className="divide-y divide-border">
                    {departments.data.map((department) => (
                        <div key={department.dept_code} className={cn(GRID, 'py-3.5')}>
                            <span className="font-mono text-sm text-ink-muted">
                                {department.dept_code}
                            </span>

                            <span className="truncate text-[15px]">{department.name}</span>

                            <span className="text-right font-mono text-sm tabular-nums text-ink-muted">
                                {department.extension}
                            </span>

                            {/* 인원을 못 세었으면 0이 아니라 모른다고 표시한다 */}
                            <span className="text-right font-mono text-sm tabular-nums text-ink-muted">
                                {members.isSuccess ? (headcount.get(department.name) ?? 0) : '-'}
                            </span>
                        </div>
                    ))}
                </div>
            </ListFrame>

            <p className="mt-4 text-xs text-ink-faint">
                인원은 재직 중인 계정만 셉니다
            </p>
        </div>
    );
}
