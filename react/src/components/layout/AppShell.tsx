import {Outlet} from 'react-router-dom';
import Header from './Header';
import Sidebar from './Sidebar';

export default function AppShell(){
    return (
        <div className= "flex min-h-dvh bg-background text-foreground">
            <Sidebar />
            <div className="flex min-h-dvh flex-1 flex-col">
                <Header />
                <main className="flex-1 overflow-auto">
                    <Outlet />
                </main>
            </div>
        </div>
    );
}