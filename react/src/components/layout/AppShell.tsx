import {Outlet} from 'react-router-dom';
import Header from './Header';
import Sidebar from './Sidebar';
import { CONTAINER } from './container';
import { AnalysisWatcher } from '@/components/AnalysisWatcher';
import { UploadProvider } from '@/components/upload/UploadProvider';
import { Toaster } from '@/components/ui/sonner';

// UploadProvider가 셸 안에 있어야 화면을 옮겨도 업로드가 이어진다.
// 레이아웃 라우트라 자식 라우트가 바뀌어도 언마운트되지 않는다.
export default function AppShell(){
    return (
        <UploadProvider>
            <div className= "flex min-h-dvh bg-background text-foreground">
                <Sidebar />
                <div className="flex min-h-dvh flex-1 flex-col">
                    <Header />
                    <main className="flex-1 overflow-auto">
                        <div className={CONTAINER + ' p-6'}>
                            <Outlet />
                        </div>
                    </main>
                </div>

                <AnalysisWatcher />
                <Toaster position="bottom-right" />
            </div>
        </UploadProvider>
    );
}