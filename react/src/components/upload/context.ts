import { createContext, useContext } from 'react';

export interface UploadItem {
    id : string;
    batchId : string;
    filename : string;
    uploadUrl : string;
    file : File;
    progress : number;
    status : 'waiting' | 'uploading' | 'done' | 'failed';
}

export interface UploadContextValue {
    items : UploadItem[];
    enqueue : (
        batchId : string,
        modelVersionId : string | undefined,
        files : { file : File; uploadUrl : string; filename : string }[],
    ) => void;
    retry : (id : string) => void;
    clearFinished : () => void;
}

export const UploadContext = createContext<UploadContextValue | null>(null);

export function useUploads() : UploadContextValue {
    const ctx = useContext(UploadContext);
    if (!ctx) throw new Error('useUploads must be used inside UploadProvider');
    return ctx;
}