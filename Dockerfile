# 构建阶段
FROM golang:alpine AS builder

WORKDIR /app

# 设置构建环境变量（GOTOOLCHAIN=auto 会自动下载需要的 Go 版本）
ENV CGO_ENABLED=1 GOOS=linux GOARCH=amd64 GOTOOLCHAIN=auto

# 安装必要的构建依赖（SQLite 需要）
RUN apk add --no-cache gcc musl-dev sqlite-dev

# 预先拷贝 go.mod/go.sum 以利用 Docker 缓存
COPY go.mod go.sum ./
RUN go mod download

# 拷贝源代码并构建
COPY . .
RUN go build -o octopus .

# 运行阶段
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
