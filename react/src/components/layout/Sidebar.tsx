import { NavLink } from 'react-router-dom';

import { getJobs } from '@/api';
import { needsReview } from '@/lib/decision';
import { cn } from '@/lib/utils';
import { NAV_GROUPS } from './nav';

export default function Sidebar() {
    const reviewCount = getJobs().filter((job) => needsReview(job.result)).length;

    return (
        <aside className="flex w-60 shrink-0 flex-col border-r border-border bg-sidebar">
            <div className="flex items-center gap-2 border-b border-border px-5 py-4">
                <span className="size-2.5 rounded-full bg-brand" />
                <span className="text-sm font-semibold tracking-tight">sTIL CDSS</span>
            </div>

            <nav className="flex-1 overflow-y-auto px-3 py-4">
                {NAV_GROUPS.map((group) => (
                    <div key={group.title} className="mb-5 last:mb-0">
                        <div className="px-2 pb-1.5 text-[11px] font-medium text-ink-faint">
                            {group.title}
                        </div>

                        {group.items.map((item) => {
                            const Icon = item.icon;
                            const count = item.badge === 'review' ? reviewCount : 0;

                            return (
                                <NavLink
                                    key={item.to}
                                    to={item.to}
                                    end={item.to === '/'}
                                    className={({ isActive }) =>
                                        cn(
                                            'flex items-center justify-between rounded-md px-2 py-2 text-sm transition-colors',
                                            isActive
                                                ? 'bg-brand-soft font-medium text-ink'
                                                : 'text-ink-muted hover:bg-brand-soft/60 hover:text-ink',
                                        )
                                    }
                                >
                                    <span className="flex items-center gap-2">
                                        <Icon size={15} />
                                        {item.label}
                                    </span>

                                    {count > 0 && (
                                        <span className="rounded-full bg-decision-abstain px-1.5 py-0.5 text-[11px] font-semibold text-on-brand">
                                            {count}
                                        </span>
                                    )}
                                </NavLink>
                            );
                        })}
                    </div>
                ))}
            </nav>
        </aside>
    );
}
