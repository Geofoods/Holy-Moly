FROM python:3.12-slim

WORKDIR /app

COPY level_server.py .

ENV PORT=8787
EXPOSE 8787
VOLUME ["/app/data"]

CMD ["python", "level_server.py", "--host", "0.0.0.0", "--data-dir", "/app/data"]
