#!/bin/bash

# Nginx Manager 一键部署脚本 (Linux版本)
# 使用预构建的镜像快速部署，无需源码

set -e

# ==========================
# 配置
# ==========================
IMAGE_NAME="docker.io/wtation/nginx-manager:latest"
CONFIG_FILE="config.env"
COMPOSE_FILE="docker-compose.yml"

# ==========================
# UI Helpers
# ==========================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}ℹ${NC} $*"; }
ok()    { echo -e "${GREEN}✓${NC} $*"; }
warn()  { echo -e "${YELLOW}!${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*"; }

header() {
  echo -e "${CYAN}============================================${NC}"
  echo -e "${CYAN}$*${NC}"
  echo -e "${CYAN}============================================${NC}"
}

# ==========================
# 主要功能
# ==========================

# 检查Docker环境
check_docker() {
  info "检查Docker环境..."

  if ! command -v docker &> /dev/null; then
    error "Docker未找到。请安装Docker。"
    echo "安装命令: curl -fsSL https://get.docker.com | sh"
    return 1
  fi

  if ! docker info &> /dev/null; then
    error "Docker服务未运行。请启动Docker服务。"
    echo "启动命令: sudo systemctl start docker"
    return 1
  fi

  ok "Docker环境正常"
}

# 检查和创建配置文件
init_config() {
  info "初始化配置..."

  # 创建默认配置文件
  if [ ! -f "$CONFIG_FILE" ]; then
    info "创建默认 config.env..."
    cat > "$CONFIG_FILE" << 'EOF'
# Nginx Manager Configuration
EXTERNAL_HTTP_PORT=7000
EXTERNAL_HTTPS_PORT=8443
INTERNAL_HTTP_PORT=5000
INTERNAL_HTTPS_PORT=5001
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443
DATA_BASE_DIR=./dockernpm-data
DATABASE_PATH=/app/data/nginxmanager.db
ASPNETCORE_ENVIRONMENT=Production
EOF
    ok "已创建 $CONFIG_FILE"
  else
    ok "配置文件已存在"
  fi
}

# 自动创建目录结构
create_directories() {
  info "创建数据目录结构..."

  directories=(
    "./dockernpm-data"
    "./dockernpm-data/data"
    "./dockernpm-data/nginx-instances"
    "./dockernpm-data/ssl"
    "./dockernpm-data/logs"
    "./dockernpm-data/www"
    "./dockernpm-data/temp"
  )

  for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
      mkdir -p "$dir"
      echo "  ✓ Created: $dir"
    else
      echo "  ✓ Exists: $dir"
    fi
  done

  ok "目录结构准备完成"
}

# 检查镜像
check_image() {
  info "检查Docker镜像..."

  # 检查完整镜像名
  if docker images "$IMAGE_NAME" --format "{{.Repository}}:{{.Tag}}" | grep -q "$IMAGE_NAME"; then
    ok "镜像已存在: $IMAGE_NAME"
    return 0
  fi

  # 检查简化镜像名 (去掉docker.io前缀)
  SHORT_NAME=$(echo "$IMAGE_NAME" | sed 's|^docker\.io/||')
  if docker images "$SHORT_NAME" --format "{{.Repository}}:{{.Tag}}" | grep -q "$SHORT_NAME"; then
    ok "镜像已存在: $SHORT_NAME"
    return 0
  fi

  warn "镜像不存在: $IMAGE_NAME"
  return 1
}

# 部署服务
deploy_services() {
  header "🚀 开始部署 Nginx Manager"

  # 停止可能存在的旧服务
  info "停止现有服务..."
  docker-compose --env-file "$CONFIG_FILE" down 2>/dev/null || true

  # 启动服务
  info "启动服务..."
  if docker-compose --env-file "$CONFIG_FILE" up -d; then
    ok "服务启动成功"
    return 0
  else
    error "服务启动失败"
    return 1
  fi
}

# 验证部署
verify_deployment() {
  info "验证部署..."

  sleep 5

  # 检查容器状态
  echo "容器状态:"
  docker-compose --env-file "$CONFIG_FILE" ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

  # 测试健康检查
  if curl -f http://localhost:7000/health --max-time 10 &>/dev/null; then
    ok "健康检查通过"
  else
    warn "健康检查失败 - 服务可能仍在启动中"
  fi
}

# 显示部署信息
show_deployment_info() {
  header "🎉 Nginx Manager 部署成功！"

  echo -e "${GREEN}🌐 访问地址:${NC}"
  echo -e "   Web界面: ${YELLOW}http://localhost:7000${NC}"
  echo -e "   HTTPS界面: ${YELLOW}https://localhost:8443${NC}"
  echo ""

  echo -e "${CYAN}📊 管理命令:${NC}"
  echo "   查看状态: docker-compose --env-file $CONFIG_FILE ps"
  echo "   查看日志: docker-compose --env-file $CONFIG_FILE logs -f"
  echo "   停止服务: docker-compose --env-file $CONFIG_FILE down"
  echo "   重启服务: docker-compose --env-file $CONFIG_FILE restart"
  echo ""

  echo -e "${CYAN}📁 数据目录:${NC}"
  echo "   ./dockernpm-data/"
  echo ""

  echo -e "${CYAN}⚙️ 配置:${NC}"
  echo "   编辑 $CONFIG_FILE 可修改端口和设置"
}

# ==========================
# 主函数
# ==========================

main() {
  header "Nginx Manager 一键部署 (Linux)"

  # 检查Docker环境
  if ! check_docker; then
    exit 1
  fi

  # 检查镜像
  if ! check_image; then
    echo ""
    info "拉取Docker镜像..."
    if docker pull "$IMAGE_NAME"; then
      ok "镜像拉取成功"
    else
      error "镜像拉取失败"
      echo "请检查网络连接后重试"
      exit 1
    fi
  fi

  # 初始化配置
  init_config

  # 创建目录结构
  create_directories

  # 部署服务
  if deploy_services; then
    # 验证部署
    verify_deployment

    # 显示信息
    show_deployment_info
  else
    error "部署失败"
    exit 1
  fi
}

# 检查是否以root用户运行（如果需要）
if [ "$EUID" -eq 0 ]; then
  warn "建议不要以root用户运行"
  echo "如果遇到权限问题，请考虑使用普通用户"
fi

# 执行主函数
main "$@"
