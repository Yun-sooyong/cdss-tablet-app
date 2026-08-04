import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ThemeProvider } from 'next-themes';

import { Toaster } from '@/components/ui/sonner';
import AppRoutes from '@/routes';

// staleTime 0 >> 분석 상태가 초 단위로 바뀐다
const queryClient = new QueryClient({
    defaultOptions: {
        queries: {
            staleTime: 0,
            retry: 1,
            refetchOnWindowFocus: false,
        },
    },
});

// Toaster는 로그인·가입에서도 떠야 해서 셸이 아니라 여기에 둔다
function App() {
    return (
        <ThemeProvider
            attribute="class"
            defaultTheme="light"
            enableSystem={false}
            storageKey="cdss.theme"
            disableTransitionOnChange
        >
            <QueryClientProvider client={queryClient}>
                <div className="min-h-screen bg-background text-foreground">
                    <AppRoutes />
                </div>

                <Toaster position="bottom-right" />
            </QueryClientProvider>
        </ThemeProvider>
    );
}

export default App;
