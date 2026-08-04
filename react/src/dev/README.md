# src/dev

실제 이미지 URL 계약이 나오면 **이 폴더째 삭제한다.**

`SlideViewer`가 `originalUrl` / `maskUrl` 이 없을 때만 여기 플레이스홀더를 그린다.
URL이 생기면 자동으로 쓰이지 않으므로, 폴더를 지우고 `SlideViewer`의 fallback 두 줄만
빼면 끝난다. 지운 뒤 `npx tsc -b` 를 돌리면 남은 사용처가 전부 에러로 드러난다.

`api/fixtures/` 와 혼동하지 말 것. fixtures 는 영구 보관이다.
