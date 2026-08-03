FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DJANGO_SETTINGS_MODULE=config.settings.prod

WORKDIR /app

# psycopg[binary]는 wheel로 오지만, 안전하게 빌드 도구 최소만 설치
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY backend/ .

# collectstatic은 DB/시크릿 없이도 돌아가야 하므로 빌드 타임에 더미 값만 채워 실행
RUN DJANGO_SECRET_KEY=build-time-placeholder \
    DATABASE_URL=postgresql://user:pass@/db?host=/tmp \
    python manage.py collectstatic --noinput

EXPOSE 8080

# Cloud Run은 $PORT로 리슨 포트를 주입한다 (기본 8080).
CMD exec gunicorn config.wsgi:application --bind 0.0.0.0:${PORT:-8080} --workers 2 --threads 4 --timeout 60
