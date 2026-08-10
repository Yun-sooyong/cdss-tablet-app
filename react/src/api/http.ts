const BASE = (import.meta.env.VITE_API_BASE_URL ?? '').replace(/\/$/, '');

const SESSION_KEY = 'cdss.session';

export interface Session {
    access : string;
    refresh : string;
    staff_id : string;
}

// readSession
export const readSession = () : Session | null => {
    try {
        const raw = localStorage.getItem(SESSION_KEY);
        return raw ? (JSON.parse(raw) as Session) : null;
    } catch {
        return null;
    }
};

let session : Session | null = readSession();

export const getSession = () : Session | null => session;

export const setSession = (next : Session | null) : void => {
    session = next;

    if (next) localStorage.setItem(SESSION_KEY, JSON.stringify(next));
    else localStorage.removeItem(SESSION_KEY);
};

export class ApiError extends Error {
    status : number;
    body : unknown;

    constructor(status : number, message : string, body : unknown) {
        super(message);
        this.name = 'ApiError';
        this.status = status;
        this.body = body;
    }
}

// messageOf 
function messageOf(body : unknown, status : number) : string {
    if (typeof body === 'string' && body) return body;

    if (Array.isArray(body)) {
        const first = body.find((v) => typeof v === 'string');
        if (first) return first as string;
    }

    if (body && typeof body === 'object') {
        const record = body as Record<string, unknown>;

        if (typeof record.detail === 'string') return record.detail;

        for (const value of Object.values(record)) {
            if (typeof value === 'string') return value;
            if (Array.isArray(value)) {
                const first = value.find((v) => typeof v === 'string');
                if (first) return first as string;
            }
        }
    }

    return `요청에 실패했습니다. (${status})`;
}

async function parse(response : Response) : Promise<unknown> {
    if (response.status === 204) return undefined;

    const text = await response.text();
    if (!text) return undefined;

    try {
        return JSON.parse(text);
    } catch {
        return text;
    }
}

// endSession >> 세션이 죽으면 남은 화면은 401만 반복한다. 로그인으로 되돌린다
function endSession() : void {
    setSession(null);

    if (!window.location.pathname.startsWith('/login')) {
        window.location.assign('/login');
    }
}

// refreshing
let refreshing : Promise<boolean> | null = null;

async function refreshAccess() : Promise<boolean> {
    const current = session;
    if (!current?.refresh) return false;

    const response = await fetch(`${BASE}/api/v1/auth/login/refresh/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ refresh: current.refresh }),
    });

    if (!response.ok) {
        endSession();
        return false;
    }

    const body = (await parse(response)) as { access? : string; refresh? : string };
    if (!body?.access) {
        endSession();
        return false;
    }

    setSession({ ...current, access: body.access, refresh: body.refresh ?? current.refresh });
    return true;
}

function send(path : string, method : string, body? : unknown) : Promise<Response> {
    const headers : Record<string, string> = {};
    if (body !== undefined) headers['Content-Type'] = 'application/json';
    if (session?.access) headers.Authorization = `Bearer ${session.access}`;

    return fetch(`${BASE}${path}`, {
        method,
        headers,
        body: body === undefined ? undefined : JSON.stringify(body),
    });
}

async function request<T>(path : string, method : string, body? : unknown) : Promise<T> {
    let response = await send(path, method, body);

    if (response.status === 401 && session?.refresh) {
        refreshing = refreshing ?? refreshAccess().finally(() => {
            refreshing = null;
        });

        if (await refreshing) response = await send(path, method, body);
    }

    const parsed = await parse(response);

    if (!response.ok) {
        throw new ApiError(response.status, messageOf(parsed, response.status), parsed);
    }

    return parsed as T;
}

export const get = <T>(path : string) : Promise<T> => request<T>(path, 'GET');

export const post = <T>(path : string, body? : unknown) : Promise<T> =>
    request<T>(path, 'POST', body);

export const patch = <T>(path : string, body? : unknown) : Promise<T> =>
    request<T>(path, 'PATCH', body);

export const del = <T>(path : string) : Promise<T> => request<T>(path, 'DELETE');

// putFile
export const putFile = (
    url : string,
    file : File,
    contentType : string,
    onProgress : (percent : number) => void,
) : Promise<void> =>
    new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();

        xhr.upload.onprogress = (e) => {
            if (e.lengthComputable) onProgress((e.loaded / e.total) * 100);
        };
        xhr.onload = () => {
            if (xhr.status >= 200 && xhr.status < 300) resolve();
            else reject(new Error(`업로드에 실패했습니다. (${xhr.status})`));
        };
        xhr.onerror = () => reject(new Error('업로드 중 연결이 끊겼습니다.'));
        xhr.onabort = () => reject(new Error('업로드가 취소되었습니다.'));

        xhr.open('PUT', url);
        xhr.setRequestHeader('Content-Type', contentType);
        xhr.send(file);
    });

// query
export const query = (
    params : Record<string, string | number | boolean | undefined>,
) : string => {
    const search = new URLSearchParams();

    for (const [key, value] of Object.entries(params)) {
        // undefined만 거름
        if (value !== undefined && value !== '') search.set(key, String(value));
    }

    const text = search.toString();
    return text ? `?${text}` : '';
};