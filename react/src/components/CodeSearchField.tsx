import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Search } from 'lucide-react';

import { FIELD_INPUT } from '@/components/form';
import { cn } from '@/lib/utils';

/* 표준코드(병명·약품) 고르기 >> 서버가 두 글자 미만은 안 내려준다 */
export function CodeSearchField<T>({
    label,
    placeholder,
    queryKey,
    search,
    codeOf,
    labelOf,
    hintOf,
    onPick,
}: {
    label : string;
    placeholder : string;
    queryKey : (q : string) => readonly unknown[];
    search : (q : string) => Promise<T[]>;
    codeOf : (item : T) => string;
    labelOf : (item : T) => string;
    hintOf? : (item : T) => string;
    onPick : (item : T) => void;
}) {
    const [draft, setDraft] = useState('');
    const [q, setQ] = useState('');

    // 타이핑마다 요청하지 않는다
    useEffect(() => {
        const id = setTimeout(() => setQ(draft.trim()), 300);
        return () => clearTimeout(id);
    }, [draft]);

    const enabled = q.length >= 2;
    const results = useQuery({
        queryKey: queryKey(q),
        queryFn: () => search(q),
        enabled,
    });

    return (
        <div>
            <label className="block">
                <span className="mb-1.5 block text-xs text-ink-muted">{label}</span>
                <span className="relative block">
                    <Search
                        size={15}
                        className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-ink-faint"
                    />
                    <input
                        value={draft}
                        onChange={(e) => setDraft(e.target.value)}
                        placeholder={placeholder}
                        className={`${FIELD_INPUT} pl-9`}
                    />
                </span>
            </label>

            {draft.trim().length > 0 && !enabled && (
                <p className="mt-1.5 text-xs text-ink-faint">두 글자 이상 입력하세요</p>
            )}

            {enabled && results.isSuccess && (
                <div className="mt-1.5 max-h-56 overflow-y-auto rounded-md border border-border">
                    {results.data.length === 0 ? (
                        <p className="px-3 py-4 text-center text-sm text-ink-faint">
                            검색 결과가 없습니다
                        </p>
                    ) : (
                        <div className="divide-y divide-border">
                            {results.data.map((item) => (
                                <button
                                    key={codeOf(item)}
                                    type="button"
                                    onClick={() => {
                                        onPick(item);
                                        setDraft('');
                                        setQ('');
                                    }}
                                    className={cn(
                                        'flex w-full items-baseline gap-2 px-3 py-2 text-left',
                                        'transition-colors hover:bg-brand-soft/50',
                                    )}
                                >
                                    <span className="min-w-0 flex-1 truncate text-sm">
                                        {labelOf(item)}
                                    </span>
                                    {hintOf && (
                                        <span className="shrink-0 truncate text-xs text-ink-faint">
                                            {hintOf(item)}
                                        </span>
                                    )}
                                    <span className="shrink-0 font-mono text-xs text-ink-faint">
                                        {codeOf(item)}
                                    </span>
                                </button>
                            ))}
                        </div>
                    )}
                </div>
            )}
        </div>
    );
}
