# syntax=docker/dockerfile:1.6
# ---------------------------------------------------------------
# 三阶段构建 —— 适用于 Zeabur / 任何标准 CI 环境(全源码在线构建)
#   Stage 1  frontend   Node 20 构建 Vue3 前端
#   Stage 2  backend    Go 构建后端 + goose
#   Stage 3  runtime    Alpine 精简运行时
# ---------------------------------------------------------------

# ---- Stage 1: 前端 ----
FROM node:20-alpine AS frontend
WORKDIR /web
COPY web/package.json web/package-lock.json* web/yarn.lock* web/pnpm-lock.yaml* ./
RUN npm install --frozen-lockfile 2>/dev/null || npm install
COPY web/ .
RUN npm run build

# ---- Stage 2: Go 后端 + goose ----
FROM golang:1.26-alpine AS backend
WORKDIR /app
RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

# 安装 goose 迁移工具
RUN go install github.com/pressly/goose/v3/cmd/goose@latest

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s" \
    -o /app/gpt2api \
    ./cmd/server

# ---- Stage 3: 运行时 ----
FROM alpine:3.20

RUN apk add --no-cache ca-certificates tzdata curl bash mariadb-client \
    && update-ca-certificates \
    && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone

WORKDIR /app

COPY --from=backend /app/gpt2api            /app/gpt2api
COPY --from=backend /root/go/bin/goose      /usr/local/bin/goose
COPY --from=frontend /web/dist              /app/web/dist
COPY sql                                    /app/sql
COPY configs/config.example.yaml           /app/configs/config.yaml
COPY deploy/entrypoint.sh                  /app/entrypoint.sh

RUN sed -i 's/\r$//' /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh /app/gpt2api \
    && mkdir -p /app/data/backups /app/logs

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
    CMD curl -fsS http://localhost:8080/healthz || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["/app/gpt2api", "-c", "/app/configs/config.yaml"]
