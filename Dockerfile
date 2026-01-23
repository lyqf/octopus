########## 前端构建阶段 ##########
FROM node:20-alpine AS web-builder

WORKDIR /web

# 启用 corepack 以使用 pnpm
RUN corepack enable

# 拷贝前端依赖文件
COPY web/package.json web/pnpm-lock.yaml ./

# 安装依赖
RUN pnpm install --frozen-lockfile

# 拷贝前端源码
COPY web ./

# 构建前端（生成 out 目录）
RUN pnpm run build

########## 后端构建阶段 ##########
FROM golang:1.24-alpine AS builder

WORKDIR /app

# 设置构建环境变量
ENV CGO_ENABLED=1 GOOS=linux GOARCH=amd64

# 安装必要的构建依赖（SQLite 需要）
RUN apk add --no-cache gcc musl-dev sqlite-dev

# 预先拷贝 go.mod/go.sum 以利用 Docker 缓存
COPY go.mod go.sum ./
RUN go mod download

# 拷贝后端源代码
COPY . .

# 从前端构建阶段复制构建产物到 static/out
COPY --from=web-builder /web/out ./static/out

# 构建 Go 应用（会自动嵌入 static/out 里的前端文件）
RUN go build -o octopus .

########## 运行阶段 ##########
FROM alpine:3.20

WORKDIR /app

# 安装运行时依赖（SQLite 和 CA 证书）
RUN apk add --no-cache ca-certificates tzdata sqlite && \
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    rm -rf /var/cache/apk/*

# 从构建阶段复制可执行文件
COPY --from=builder /app/octopus /app/octopus

# 创建 data 目录（用于存放配置和数据库）
RUN mkdir -p /app/data && chmod 755 /app/data

# 暴露端口（默认 8080，可通过环境变量 OCTOPUS_SERVER_PORT 修改）
EXPOSE 8080

# 启动命令（和本地启动方式一致）
CMD ["./octopus", "start"]
