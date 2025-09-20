#!/bin/bash

# Nginx Manager Deployment Script (Linux)
# Interactive menu-driven deployment and management tool

set -e

# ==========================
# 配置
# ==========================
IMAGE_NAME="docker.io/wtation/nginx-manager:latest"
CONFIG_FILE="config.env"
COMPOSE_FILE="docker-compose.yml"

# 解析命令行参数
FORCE=false
SILENT=false
MENU_OPTION=""
HELP=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      HELP=true
      shift
      ;;
    --force|-f)
      FORCE=true
      shift
      ;;
    --silent|-s)
      SILENT=true
      shift
      ;;
    --menu-option|-m)
      MENU_OPTION="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# 显示帮助信息（需要在main函数之前）
if [ "$HELP" = "true" ]; then
  echo "Nginx Manager Deployment Script (Linux)"
  echo ""
  echo "Usage:"
  echo "  ./deploy.sh                    - Interactive menu mode"
  echo "  ./deploy.sh --menu-option 1    - Default installation"
  echo "  ./deploy.sh --menu-option 2    - Custom installation"
  echo "  ./deploy.sh --menu-option 3    - Maintenance menu"
  echo "  ./deploy.sh --menu-option 4    - Restore defaults"
  echo "  ./deploy.sh --silent           - Silent default installation"
  echo "  ./deploy.sh --force            - Force mode (override existing)"
  echo "  ./deploy.sh --help             - Show this help message"
  echo ""
  echo "Menu Options:"
  echo "  1. Default One-Click Installation"
  echo "  2. Custom Installation (configure ports, paths, etc.)"
  echo "  3. Maintenance & Management"
  echo "  4. Restore to Default Configuration"
  echo "  5. Exit"
  echo ""
  exit 0
fi

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
# Menu System Functions
# ==========================

show_main_menu() {
  header "Nginx Manager Deployment & Management Tool"

  echo "Please select an option:"
  echo ""
  echo "1. Default One-Click Installation"
  echo "2. Custom Installation (Configure ports, paths, etc.)"
  echo "3. Maintenance & Management"
  echo "4. Restore to Default Configuration"
  echo "5. Exit"
  echo ""
  echo "Current Status:"
  show_service_status
  echo ""
}

show_maintenance_menu() {
  header "Maintenance & Management"

  echo "Please select a maintenance option:"
  echo ""
  echo "1. Start Services"
  echo "2. Stop Services"
  echo "3. Restart Services"
  echo "4. Update Docker Image"
  echo "5. View Service Logs"
  echo "6. View Container Status"
  echo "7. Clean Up (Remove stopped containers)"
  echo "8. Backup Configuration"
  echo "9. Back to Main Menu"
  echo ""
}

show_service_status() {
  if docker-compose --env-file "$CONFIG_FILE" ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null; then
    echo "Services Status:"
    docker-compose --env-file "$CONFIG_FILE" ps --format "table {{.Name}}\t{{.Status}}"
  else
    echo "No services running"
  fi
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

# 默认安装
invoke_default_installation() {
  header "Default One-Click Installation"

  # 检查Docker环境
  if ! check_docker; then
    return 1
  fi

  # 检查镜像
  if ! check_image; then
    echo ""
    info "Pulling Docker image..."
    if docker pull "$IMAGE_NAME"; then
      ok "Image pulled successfully"
    else
      error "Failed to pull image"
      echo "Please check your internet connection and try again."
      return 1
    fi
  fi

  # 初始化配置
  init_config

  # 创建目录结构
  create_directories

  # 检查端口占用
  if ! check_ports; then
    return 1
  fi

  # 部署服务
  if deploy_services; then
    # 验证部署
    verify_deployment

    # 显示信息
    show_deployment_info
    return 0
  else
    error "Deployment failed"
    return 1
  fi
}

# 自定义安装
invoke_custom_installation() {
  header "Custom Installation"

  echo "This will guide you through configuring Nginx Manager with custom settings."
  echo ""

  # 获取用户配置
  if ! get_custom_configuration; then
    warn "Installation cancelled by user"
    return 1
  fi

  # 执行安装
  invoke_default_installation
}

get_custom_configuration() {
  echo "Enter custom configuration (press Enter for default values):"
  echo ""

  # HTTP Port
  while true; do
    read -p "HTTP Port for web interface (default: 7000): " input
    if [ -z "$input" ]; then
      HTTP_PORT="7000"
      break
    fi
    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le 65535 ]; then
      HTTP_PORT="$input"
      break
    else
      warn "Invalid port number. Please enter a number between 1-65535."
    fi
  done

  # HTTPS Port
  while true; do
    read -p "HTTPS Port for web interface (default: 8443): " input
    if [ -z "$input" ]; then
      HTTPS_PORT="8443"
      break
    fi
    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le 65535 ]; then
      HTTPS_PORT="$input"
      break
    else
      warn "Invalid port number. Please enter a number between 1-65535."
    fi
  done

  # Nginx HTTP Port
  while true; do
    read -p "Nginx HTTP Port (default: 80): " input
    if [ -z "$input" ]; then
      NGINX_HTTP_PORT="80"
      break
    fi
    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le 65535 ]; then
      NGINX_HTTP_PORT="$input"
      break
    else
      warn "Invalid port number. Please enter a number between 1-65535."
    fi
  done

  # Nginx HTTPS Port
  while true; do
    read -p "Nginx HTTPS Port (default: 443): " input
    if [ -z "$input" ]; then
      NGINX_HTTPS_PORT="443"
      break
    fi
    if [[ "$input" =~ ^[0-9]+$ ]] && [ "$input" -ge 1 ] && [ "$input" -le 65535 ]; then
      NGINX_HTTPS_PORT="$input"
      break
    else
      warn "Invalid port number. Please enter a number between 1-65535."
    fi
  done

  # Data Directory
  read -p "Data directory path (default: ./dockernpm-data): " input
  if [ -z "$input" ]; then
    DATA_DIR="./dockernpm-data"
  else
    DATA_DIR="$input"
  fi

  # Localhost Only
  while true; do
    read -p "Bind to localhost only? (y/n, default: y for security): " input
    if [ -z "$input" ]; then
      LOCALHOST_ONLY="true"
      break
    fi
    case "$input" in
      [Yy]|[Yy][Ee][Ss])
        LOCALHOST_ONLY="true"
        break
        ;;
      [Nn]|[Nn][Oo])
        LOCALHOST_ONLY="false"
        break
        ;;
      *)
        warn "Please enter 'y' for yes or 'n' for no."
        ;;
    esac
  done

  # Confirm configuration
  echo ""
  echo "Configuration Summary:"
  echo "HTTP Port: $HTTP_PORT"
  echo "HTTPS Port: $HTTPS_PORT"
  echo "Nginx HTTP Port: $NGINX_HTTP_PORT"
  echo "Nginx HTTPS Port: $NGINX_HTTPS_PORT"
  echo "Data Directory: $DATA_DIR"
  echo "Localhost Only: $LOCALHOST_ONLY"
  echo ""

  read -p "Proceed with this configuration? (y/N): " confirm
  case "$confirm" in
    [Yy]|[Yy][Ee][Ss])
      # Apply custom configuration to config.env
      cat > "$CONFIG_FILE" << EOF
# Nginx Manager Environment Configuration
# 修改这些变量来改变端口配置
# 只需修改这里，所有相关配置文件都会自动使用这些值

# 外部访问端口 (修改这里来改变端口)
EXTERNAL_HTTP_PORT=$HTTP_PORT
EXTERNAL_HTTPS_PORT=$HTTPS_PORT

# 内部容器端口 (通常不需要修改)
INTERNAL_HTTP_PORT=5000
INTERNAL_HTTPS_PORT=5001

# Nginx代理端口
NGINX_HTTP_PORT=$NGINX_HTTP_PORT
NGINX_HTTPS_PORT=$NGINX_HTTPS_PORT

# 数据目录配置 (修改这里来改变数据存储位置)
DATA_BASE_DIR=$DATA_DIR

# 数据库配置
DATABASE_PATH=/app/data/nginxmanager.db

# 应用环境
ASPNETCORE_ENVIRONMENT=Production

# 本地访问模式设置
# 设置为true时，HTTP端口只绑定到127.0.0.1（localhost），公网无法访问
# 设置为false时，端口绑定到所有网络接口，公网可以访问
LOCALHOST_ONLY=$LOCALHOST_ONLY
EOF
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# 维护菜单
invoke_maintenance_menu() {
  while true; do
    show_maintenance_menu
    read -p "Enter your choice (1-9): " choice

    case $choice in
      1) invoke_start_services ;;
      2) invoke_stop_services ;;
      3) invoke_restart_services ;;
      4) invoke_update_image ;;
      5) invoke_view_logs ;;
      6) invoke_view_status ;;
      7) invoke_cleanup ;;
      8) invoke_backup_config ;;
      9) return ;;
      *) warn "Invalid choice. Please enter 1-9." ;;
    esac

    if [ "$choice" != "9" ]; then
      echo ""
      read -p "Press Enter to continue..."
    fi
  done
}

# 维护功能实现
invoke_start_services() {
  header "Starting Services"

  # 生成最新的docker-compose配置
  generate_compose_file

  if docker-compose --env-file "$CONFIG_FILE" up -d; then
    ok "Services started successfully"
    show_service_status
  else
    error "Failed to start services"
  fi
}

invoke_stop_services() {
  header "Stopping Services"
  if docker-compose --env-file "$CONFIG_FILE" down; then
    ok "Services stopped successfully"
  else
    error "Failed to stop services"
  fi
}

invoke_restart_services() {
  header "Restarting Services"

  # 生成最新的docker-compose配置
  generate_compose_file

  if docker-compose --env-file "$CONFIG_FILE" restart; then
    ok "Services restarted successfully"
    show_service_status
  else
    error "Failed to restart services"
  fi
}

invoke_update_image() {
  header "Updating Docker Image"
  info "Pulling latest image..."
  if docker pull "$IMAGE_NAME"; then
    ok "Image updated successfully"

    # 生成最新的docker-compose配置
    generate_compose_file

    info "Restarting services with new image..."
    if docker-compose --env-file "$CONFIG_FILE" up -d; then
      ok "Services updated and restarted"
      show_service_status
    else
      error "Failed to restart services"
    fi
  else
    error "Failed to update image"
  fi
}

invoke_view_logs() {
  header "Service Logs"
  echo "Choose log option:"
  echo "1. View last 50 lines"
  echo "2. Follow logs (Ctrl+C to exit)"
  echo ""

  read -p "Enter choice (1-2): " log_choice
  case $log_choice in
    1)
      if docker-compose --env-file "$CONFIG_FILE" logs --tail=50; then
        :
      else
        error "Failed to view logs"
      fi
      ;;
    2)
      echo "Press Ctrl+C to exit log view"
      if docker-compose --env-file "$CONFIG_FILE" logs -f; then
        :
      else
        error "Failed to follow logs"
      fi
      ;;
    *)
      warn "Invalid choice"
      ;;
  esac
}

invoke_view_status() {
  header "Container Status"
  if docker-compose --env-file "$CONFIG_FILE" ps; then
    :
  else
    error "Failed to get status"
  fi
}

invoke_cleanup() {
  header "Cleaning Up"
  info "Removing stopped containers..."
  docker container prune -f

  info "Removing unused images..."
  docker image prune -f

  info "Removing unused volumes..."
  docker volume prune -f

  ok "Cleanup completed"
}

invoke_backup_config() {
  header "Backup Configuration"
  timestamp=$(date +"%Y%m%d_%H%M%S")
  backup_dir="backup_$timestamp"

  mkdir -p "$backup_dir"

  if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "$backup_dir/"
  fi
  if [ -f "$COMPOSE_FILE" ]; then
    cp "$COMPOSE_FILE" "$backup_dir/"
  fi
  if [ -d "dockernpm-data" ]; then
    cp -r "dockernpm-data" "$backup_dir/"
  fi

  ok "Configuration backed up to: $backup_dir"
}

# 还原默认配置
invoke_restore_defaults() {
  header "Restore to Default Configuration"

  warn "This will restore Nginx Manager to default configuration."
  warn "All custom settings will be lost."
  echo ""

  read -p "Are you sure you want to continue? (yes/no): " confirm
  if [ "$confirm" != "yes" ]; then
    info "Operation cancelled"
    return
  fi

  # Stop services
  info "Stopping services..."
  docker-compose --env-file "$CONFIG_FILE" down 2>/dev/null || true

  # Remove containers and volumes
  info "Removing containers and volumes..."
  docker-compose --env-file "$CONFIG_FILE" down -v 2>/dev/null || true

  # Remove data directory
  if [ -d "dockernpm-data" ]; then
    info "Removing data directory..."
    rm -rf "dockernpm-data"
  fi

  # Remove config files
  if [ -f "$CONFIG_FILE" ]; then
    info "Removing configuration files..."
    rm -f "$CONFIG_FILE"
  fi
  if [ -f "$COMPOSE_FILE" ]; then
    rm -f "$COMPOSE_FILE"
  fi

  ok "Restoration completed. Run the script again to perform a fresh installation."
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
# 设置为true时，HTTP端口只绑定到127.0.0.1（localhost），公网无法访问
LOCALHOST_ONLY=false
EOF
    ok "已创建 $CONFIG_FILE"
  else
    ok "配置文件已存在"
  fi
}

# 自动创建目录结构
create_directories() {
  info "创建数据目录结构..."

  # 从配置文件获取数据目录，如果不存在则使用默认值
  if [ -f "$CONFIG_FILE" ]; then
    DATA_BASE_DIR=$(grep "^DATA_BASE_DIR=" "$CONFIG_FILE" | cut -d'=' -f2)
  fi
  DATA_BASE_DIR=${DATA_BASE_DIR:-./dockernpm-data}

  directories=(
    "$DATA_BASE_DIR"
    "$DATA_BASE_DIR/data"
    "$DATA_BASE_DIR/nginx-instances"
    "$DATA_BASE_DIR/ssl"
    "$DATA_BASE_DIR/logs"
    "$DATA_BASE_DIR/www"
    "$DATA_BASE_DIR/temp"
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

# 检查端口占用
check_ports() {
  info "检查端口占用..."

  # 读取配置文件中的端口
  if [ -f "$CONFIG_FILE" ]; then
    EXTERNAL_HTTP_PORT=$(grep "^EXTERNAL_HTTP_PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
    EXTERNAL_HTTPS_PORT=$(grep "^EXTERNAL_HTTPS_PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
    NGINX_HTTP_PORT=$(grep "^NGINX_HTTP_PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
    NGINX_HTTPS_PORT=$(grep "^NGINX_HTTPS_PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
    LOCALHOST_ONLY=$(grep "^LOCALHOST_ONLY=" "$CONFIG_FILE" | cut -d'=' -f2)
  fi

  # 设置默认值
  EXTERNAL_HTTP_PORT=${EXTERNAL_HTTP_PORT:-7000}
  EXTERNAL_HTTPS_PORT=${EXTERNAL_HTTPS_PORT:-8443}
  NGINX_HTTP_PORT=${NGINX_HTTP_PORT:-80}
  NGINX_HTTPS_PORT=${NGINX_HTTPS_PORT:-443}
  LOCALHOST_ONLY=${LOCALHOST_ONLY:-false}

  ports=("$EXTERNAL_HTTP_PORT" "$EXTERNAL_HTTPS_PORT" "$NGINX_HTTP_PORT" "$NGINX_HTTPS_PORT")
  conflict_found=false

  for port in "${ports[@]}"; do
    if [ "$LOCALHOST_ONLY" = "true" ]; then
      # 检查localhost特定端口
      if lsof -i 127.0.0.1:"$port" >/dev/null 2>&1; then
        warn "本地端口 127.0.0.1:$port 已被占用"
        echo "占用进程信息:"
        lsof -i 127.0.0.1:"$port"
        conflict_found=true
      else
        echo "  ✓ 本地端口 127.0.0.1:$port 可用"
      fi
    else
      # 检查所有接口的端口
      if lsof -i :"$port" >/dev/null 2>&1; then
        warn "端口 $port 已被占用"
        echo "占用进程信息:"
        lsof -i :"$port"
        conflict_found=true
      else
        echo "  ✓ 端口 $port 可用"
      fi
    fi
  done

  if [ "$conflict_found" = true ]; then
    echo ""
    warn "检测到端口冲突！"
    echo ""
    echo "解决方案："
    echo "1. 修改 $CONFIG_FILE 中的端口配置"
    echo "2. 或者停止占用端口的进程"
    echo ""
    echo "例如，修改端口："
    echo "  EXTERNAL_HTTP_PORT=7001"
    echo "  EXTERNAL_HTTPS_PORT=8444"
    echo ""
    read -p "是否要继续尝试部署？(y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      return 1
    fi
  else
    ok "所有端口都可用"
  fi
}

# 生成docker-compose配置文件
generate_compose_file() {
  info "生成Docker Compose配置..."

  # 首先从配置文件读取变量
  if [ -f "$CONFIG_FILE" ]; then
    EXTERNAL_HTTP_PORT=$(grep "^EXTERNAL_HTTP_PORT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    EXTERNAL_HTTPS_PORT=$(grep "^EXTERNAL_HTTPS_PORT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    INTERNAL_HTTP_PORT=$(grep "^INTERNAL_HTTP_PORT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    INTERNAL_HTTPS_PORT=$(grep "^INTERNAL_HTTPS_PORT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    NGINX_HTTP_PORT=$(grep "^NGINX_HTTP_PORT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    NGINX_HTTPS_PORT=$(grep "^NGINX_HTTPS_PORT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    DATA_BASE_DIR=$(grep "^DATA_BASE_DIR=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    DATABASE_PATH=$(grep "^DATABASE_PATH=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    ASPNETCORE_ENVIRONMENT=$(grep "^ASPNETCORE_ENVIRONMENT=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
    LOCALHOST_ONLY=$(grep "^LOCALHOST_ONLY=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '\r\n')
  fi

  # 设置默认值
  EXTERNAL_HTTP_PORT=${EXTERNAL_HTTP_PORT:-7000}
  EXTERNAL_HTTPS_PORT=${EXTERNAL_HTTPS_PORT:-8443}
  INTERNAL_HTTP_PORT=${INTERNAL_HTTP_PORT:-5000}
  INTERNAL_HTTPS_PORT=${INTERNAL_HTTPS_PORT:-5001}
  NGINX_HTTP_PORT=${NGINX_HTTP_PORT:-80}
  NGINX_HTTPS_PORT=${NGINX_HTTPS_PORT:-443}
  DATA_BASE_DIR=${DATA_BASE_DIR:-./dockernpm-data}
  DATABASE_PATH=${DATABASE_PATH:-/app/data/nginxmanager.db}
  ASPNETCORE_ENVIRONMENT=${ASPNETCORE_ENVIRONMENT:-Production}
  LOCALHOST_ONLY=${LOCALHOST_ONLY:-false}

  # 根据LOCALHOST_ONLY设置确定端口绑定前缀
  if [ "$LOCALHOST_ONLY" = "true" ]; then
    HTTP_PORT_BINDING="127.0.0.1:$EXTERNAL_HTTP_PORT:$INTERNAL_HTTP_PORT"
    HTTPS_PORT_BINDING="127.0.0.1:$EXTERNAL_HTTPS_PORT:$INTERNAL_HTTPS_PORT"
    NGINX_HTTP_BINDING="127.0.0.1:$NGINX_HTTP_PORT:80"
    NGINX_HTTPS_BINDING="127.0.0.1:$NGINX_HTTPS_PORT:443"
    BINDING_MODE="本地绑定 (127.0.0.1)"
  else
    HTTP_PORT_BINDING="$EXTERNAL_HTTP_PORT:$INTERNAL_HTTP_PORT"
    HTTPS_PORT_BINDING="$EXTERNAL_HTTPS_PORT:$INTERNAL_HTTPS_PORT"
    NGINX_HTTP_BINDING="$NGINX_HTTP_PORT:80"
    NGINX_HTTPS_BINDING="$NGINX_HTTPS_PORT:443"
    BINDING_MODE="公网绑定 (0.0.0.0)"
  fi

  # 生成docker-compose.yml (使用printf避免here document的变量替换问题)
  printf "version: '3.8'\n\n" > "$COMPOSE_FILE"
  printf "services:\n" >> "$COMPOSE_FILE"
  printf "  nginx-manager:\n" >> "$COMPOSE_FILE"
  printf "    image: %s\n" "$IMAGE_NAME" >> "$COMPOSE_FILE"
  printf "    container_name: nginx-manager\n" >> "$COMPOSE_FILE"
  printf "    restart: unless-stopped\n\n" >> "$COMPOSE_FILE"
  printf "    # 端口映射 (%s)\n" "$BINDING_MODE" >> "$COMPOSE_FILE"
  printf "    ports:\n" >> "$COMPOSE_FILE"
  printf "      - %s    # HTTP端口\n" "$HTTP_PORT_BINDING" >> "$COMPOSE_FILE"
  printf "      - %s  # HTTPS端口\n" "$HTTPS_PORT_BINDING" >> "$COMPOSE_FILE"
  printf "      - %s   # Nginx HTTP端口\n" "$NGINX_HTTP_BINDING" >> "$COMPOSE_FILE"
  printf "      - %s  # Nginx HTTPS端口\n" "$NGINX_HTTPS_BINDING" >> "$COMPOSE_FILE"
  printf "\n" >> "$COMPOSE_FILE"
  printf "    environment:\n" >> "$COMPOSE_FILE"
  printf "      - ASPNETCORE_ENVIRONMENT=%s\n" "$ASPNETCORE_ENVIRONMENT" >> "$COMPOSE_FILE"
  printf "      - ASPNETCORE_URLS=http://+:%s;https://+:%s\n" "$INTERNAL_HTTP_PORT" "$INTERNAL_HTTPS_PORT" >> "$COMPOSE_FILE"
  printf "      - DOTNET_RUNNING_IN_CONTAINER=true\n" >> "$COMPOSE_FILE"
  printf "      - ConnectionStrings__Default=Data Source=%s\n" "$DATABASE_PATH" >> "$COMPOSE_FILE"
  printf "      - NginxManager__DefaultDataDir=/app/data\n" >> "$COMPOSE_FILE"
  printf "      - NginxManager__DefaultNginxDir=/app/nginx-instances\n" >> "$COMPOSE_FILE"
  printf "      - NginxManager__DefaultSslDir=/app/ssl\n" >> "$COMPOSE_FILE"
  printf "      - NginxManager__DefaultLogDir=/app/logs\n" >> "$COMPOSE_FILE"
  printf "      - NginxManager__DefaultWebRootDir=/var/www/html\n\n" >> "$COMPOSE_FILE"
  printf "    volumes:\n" >> "$COMPOSE_FILE"
  printf "      - %s/data:/app/data:rw\n" "$DATA_BASE_DIR" >> "$COMPOSE_FILE"
  printf "      - %s/nginx-instances:/app/nginx-instances:rw\n" "$DATA_BASE_DIR" >> "$COMPOSE_FILE"
  printf "      - %s/ssl:/app/ssl:rw\n" "$DATA_BASE_DIR" >> "$COMPOSE_FILE"
  printf "      - %s/logs:/app/logs:rw\n" "$DATA_BASE_DIR" >> "$COMPOSE_FILE"
  printf "      - %s/www:/var/www/html:rw\n" "$DATA_BASE_DIR" >> "$COMPOSE_FILE"
  printf "      - %s/temp:/tmp:rw\n\n" "$DATA_BASE_DIR" >> "$COMPOSE_FILE"
  printf "    networks:\n" >> "$COMPOSE_FILE"
  printf "      - nginx-network\n\n" >> "$COMPOSE_FILE"
  printf "    healthcheck:\n" >> "$COMPOSE_FILE"
  printf "      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost:%s/health\"]\n" "$INTERNAL_HTTP_PORT" >> "$COMPOSE_FILE"
  printf "      interval: 30s\n" >> "$COMPOSE_FILE"
  printf "      timeout: 10s\n" >> "$COMPOSE_FILE"
  printf "      retries: 3\n" >> "$COMPOSE_FILE"
  printf "      start_period: 40s\n\n" >> "$COMPOSE_FILE"
  printf "    deploy:\n" >> "$COMPOSE_FILE"
  printf "      resources:\n" >> "$COMPOSE_FILE"
  printf "        limits:\n" >> "$COMPOSE_FILE"
  printf "          memory: 1G\n" >> "$COMPOSE_FILE"
  printf "        reservations:\n" >> "$COMPOSE_FILE"
  printf "          memory: 256M\n\n" >> "$COMPOSE_FILE"
  printf "networks:\n" >> "$COMPOSE_FILE"
  printf "  nginx-network:\n" >> "$COMPOSE_FILE"
  printf "    driver: bridge\n" >> "$COMPOSE_FILE"

  ok "Docker Compose配置生成完成 ($BINDING_MODE)"
}

# 部署服务
deploy_services() {
  header "🚀 开始部署 Nginx Manager"

  # 生成Docker Compose配置
  generate_compose_file

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
    # 尝试提供更详细的错误信息
    echo "可能的解决方案："
    echo "1. 检查端口是否被其他服务占用"
    echo "2. 修改 config.env 中的端口配置"
    echo "3. 确保Docker服务正在运行"
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
  # 从配置文件获取HTTP端口，如果不存在则使用默认值
  if [ -f "$CONFIG_FILE" ]; then
    HEALTH_PORT=$(grep "^EXTERNAL_HTTP_PORT=" "$CONFIG_FILE" | cut -d'=' -f2)
  fi
  HEALTH_PORT=${HEALTH_PORT:-7000}

  if curl -f "http://localhost:$HEALTH_PORT/health" --max-time 10 &>/dev/null; then
    ok "健康检查通过"
  else
    warn "健康检查失败 - 服务可能仍在启动中"
  fi
}

# 显示部署信息
show_deployment_info() {
  header "🎉 Nginx Manager 部署成功！"

  # 根据绑定模式显示不同的访问地址
  if [ "$LOCALHOST_ONLY" = "true" ]; then
    echo -e "${GREEN}🔒 本地访问地址 (仅限127.0.0.1/localhost):${NC}"
    echo -e "   Web界面: ${YELLOW}http://127.0.0.1:$EXTERNAL_HTTP_PORT${NC} 或 ${YELLOW}http://localhost:$EXTERNAL_HTTP_PORT${NC}"
    echo -e "   HTTPS界面: ${YELLOW}https://127.0.0.1:$EXTERNAL_HTTPS_PORT${NC} 或 ${YELLOW}https://localhost:$EXTERNAL_HTTPS_PORT${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  注意: 端口只绑定到本地地址，公网无法访问${NC}"
  else
    echo -e "${GREEN}🌐 访问地址:${NC}"
    echo -e "   Web界面: ${YELLOW}http://localhost:$EXTERNAL_HTTP_PORT${NC}"
    echo -e "   HTTPS界面: ${YELLOW}https://localhost:$EXTERNAL_HTTPS_PORT${NC}"
    echo -e "   公网访问: ${YELLOW}http://<服务器IP>:$EXTERNAL_HTTP_PORT${NC}"
  fi
  echo ""

  echo -e "${CYAN}📊 管理命令:${NC}"
  echo "   查看状态: docker-compose --env-file $CONFIG_FILE ps"
  echo "   查看日志: docker-compose --env-file $CONFIG_FILE logs -f"
  echo "   停止服务: docker-compose --env-file $CONFIG_FILE down"
  echo "   重启服务: docker-compose --env-file $CONFIG_FILE restart"
  echo ""

  echo -e "${CYAN}📁 数据目录:${NC}"
  # 从配置文件获取数据目录，如果不存在则使用默认值
  if [ -f "$CONFIG_FILE" ]; then
    DATA_DIR=$(grep "^DATA_BASE_DIR=" "$CONFIG_FILE" | cut -d'=' -f2)
  fi
  DATA_DIR=${DATA_DIR:-./dockernpm-data}
  echo "   $DATA_DIR/"
  echo ""

  echo -e "${CYAN}⚙️ 配置:${NC}"
  echo "   编辑 $CONFIG_FILE 可修改端口和设置"
  if [ "$LOCALHOST_ONLY" = "false" ]; then
    echo "   将 LOCALHOST_ONLY 设置为 true 可限制为本地访问"
  fi
}

# ==========================
# 主函数
# ==========================

main() {

  # 静默模式
  if [ "$SILENT" = "true" ]; then
    invoke_default_installation
    exit $?
  fi

  # 直接执行指定选项
  if [ -n "$MENU_OPTION" ]; then
    case $MENU_OPTION in
      1)
        invoke_default_installation
        exit $?
        ;;
      2)
        invoke_custom_installation
        exit $?
        ;;
      3)
        invoke_maintenance_menu
        exit 0
        ;;
      4)
        invoke_restore_defaults
        exit 0
        ;;
      *)
        error "Invalid menu option: $MENU_OPTION"
        exit 1
        ;;
    esac
  fi

  # 交互式菜单模式
  while true; do
    show_main_menu
    read -p "Enter your choice (1-5): " choice

    case $choice in
      1)
        if invoke_default_installation; then
          echo ""
          read -p "Press Enter to return to main menu..."
        fi
        ;;
      2)
        if invoke_custom_installation; then
          echo ""
          read -p "Press Enter to return to main menu..."
        fi
        ;;
      3)
        invoke_maintenance_menu
        ;;
      4)
        invoke_restore_defaults
        echo ""
        read -p "Press Enter to return to main menu..."
        ;;
      5)
        echo "Goodbye!"
        exit 0
        ;;
      *)
        warn "Invalid choice. Please enter 1-5."
        sleep 2
        ;;
    esac
  done
}

# 检查是否以root用户运行（如果需要）
if [ "$EUID" -eq 0 ]; then
  warn "建议不要以root用户运行"
  echo "如果遇到权限问题，请考虑使用普通用户"
fi

# 执行主函数
main "$@"
