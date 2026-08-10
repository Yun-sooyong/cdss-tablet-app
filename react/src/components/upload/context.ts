import { createContext, useContext } from 'react';

export interface UploadItem {
    id : string;
    batchId : string;
    filename : string;
    uploadUrl : string;
    contentType : string;
    file : File;
    progress : number;
    status : 'waiting' | 'uploading' | 'done' | 'failed';
}

export interface UploadContextValue {
    items : UploadItem[];
    enqueue : (
        batchId : string,
        modelVersionId : string | undefined,
        files : { file : File; uploadUrl : string; contentType : string; filename : string }[],
    ) => void;
    retry : (id : string) => void;
    clearFinished : () => void;
}

// stalledBatchIds
export const stalledBatchIds = (items : UploadItem[]) : Set<string> => {
    const busy = new Set<string>();
    const failed = new Set<string>();

    for (const it of items) {
        if (it.status === 'waiting' || it.status === 'uploading') busy.add(it.batchId);
        else if (it.status === 'failed') failed.add(it.batchId);
    }

    return new Set([...failed].filter((id) => !busy.has(id)));
};

export const UploadContext = createContext<UploadContextValue | null>(null);

export function useUploads() : UploadContextValue {
    const ctx = useContext(UploadContext);
    if (!ctx) throw new Error('useUploads must be used inside UploadProvider');
    return ctx;
}