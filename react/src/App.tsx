import AppRoutes from '@/routes';

// 블록 D에서 AppRoutes를 AppShell(사이드바 + 헤더)로
function App() {
  return (
    <div className="min-h-screen bg-background text-foreground">
      <AppRoutes />
    </div>
  );
}

export default App;
