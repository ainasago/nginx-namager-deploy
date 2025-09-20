# Nginx Manager 一键部署脚本
# 使用预构建的镜像快速部署，无需源码

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# ==========================
# 配置
# ==========================
$IMAGE_NAME = "docker.io/wtation/nginx-manager:latest"
$CONFIG_FILE = "config.env"
$COMPOSE_FILE = "docker-compose.yml"

# ==========================
# UI Helpers
# ==========================
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$CYAN = "Cyan"

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor $CYAN
}

function Write-Ok {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor $GREEN
}

function Write-Warn {
    param([string]$Message)
    Write-Host "! $Message" -ForegroundColor $YELLOW
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $RED
}

function Write-Header {
    param([string]$Message)
    Write-Host "============================================" -ForegroundColor $CYAN
    Write-Host "$Message" -ForegroundColor $CYAN
    Write-Host "============================================" -ForegroundColor $CYAN
}

# ==========================
# 主要功能
# ==========================

# 检查Docker环境
function Test-DockerEnv {
    Write-Info "Checking Docker environment..."

    try {
        $dockerVersion = docker --version 2>$null
        Write-Ok "Docker found"
        return $true
    }
    catch {
        Write-Error "Docker not found. Please install Docker Desktop."
        Write-Host "Download: https://www.docker.com/products/docker-desktop"
        return $false
    }

    try {
        docker info 2>$null | Out-Null
        Write-Ok "Docker daemon is running"
        return $true
    }
    catch {
        Write-Error "Docker daemon is not running. Please start Docker Desktop."
        return $false
    }
}

# 检查和创建配置文件
function Initialize-Config {
    Write-Info "Initializing configuration..."

    # 创建默认配置文件
    if (-not (Test-Path $CONFIG_FILE)) {
        Write-Info "Creating default config.env..."
        $defaultConfig = @"
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
"@
        $defaultConfig | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
        Write-Ok "Created $CONFIG_FILE"
    } else {
        Write-Ok "Config file exists"
    }
}

# 自动创建目录结构
function New-DataDirectories {
    Write-Info "Creating data directory structure..."

    $directories = @(
        "./dockernpm-data",
        "./dockernpm-data/data",
        "./dockernpm-data/nginx-instances",
        "./dockernpm-data/ssl",
        "./dockernpm-data/logs",
        "./dockernpm-data/www",
        "./dockernpm-data/temp"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            try {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Host "  ✓ Created: $dir" -ForegroundColor Green
            }
            catch {
                Write-Warn "Failed to create: $dir"
            }
        } else {
            Write-Host "  ✓ Exists: $dir" -ForegroundColor Gray
        }
    }

    Write-Ok "Directory structure ready"
}

# 检查镜像
function Test-Image {
    Write-Info "Checking Docker image..."

    try {
        # 检查完整镜像名
        $fullImage = docker images $IMAGE_NAME --format "{{.Repository}}:{{.Tag}}"
        if ($fullImage -and $fullImage.Contains($IMAGE_NAME)) {
            Write-Ok "Image found: $IMAGE_NAME"
            return $true
        }

        # 检查简化镜像名 (去掉docker.io前缀)
        $shortName = $IMAGE_NAME -replace "^docker\.io/", ""
        $shortImage = docker images $shortName --format "{{.Repository}}:{{.Tag}}"
        if ($shortImage -and $shortImage.Contains($shortName)) {
            Write-Ok "Image found: $shortName"
            return $true
        }

        Write-Warn "Image not found: $IMAGE_NAME"
        Write-Host "Pull command: docker pull $IMAGE_NAME"
        return $false
    }
    catch {
        Write-Error "Failed to check image: $_"
        return $false
    }
}

# 部署服务
function Start-Deployment {
    Write-Header "🚀 Starting Nginx Manager Deployment"

    # 停止可能存在的旧服务
    Write-Info "Stopping existing services..."
    try {
        docker-compose --env-file $CONFIG_FILE down 2>$null | Out-Null
    }
    catch {
        # 忽略错误
    }

    # 启动服务
    Write-Info "Starting services..."
    try {
        $startResult = docker-compose --env-file $CONFIG_FILE up -d 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Services started successfully"
        } else {
            Write-Error "Failed to start services"
            Write-Host $startResult -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Error "Deployment failed: $_"
        return $false
    }

    return $true
}

# 验证部署
function Test-Deployment {
    Write-Info "Verifying deployment..."

    Start-Sleep -Seconds 5

    # 检查容器状态
    try {
        $containers = docker-compose --env-file $CONFIG_FILE ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
        Write-Host "Container Status:" -ForegroundColor Cyan
        Write-Host $containers
    }
    catch {
        Write-Warn "Could not get container status"
    }

    # 测试健康检查
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:7000/health" -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Ok "Health check passed"
        } else {
            Write-Warn "Health check returned status: $($response.StatusCode)"
        }
    }
    catch {
        Write-Warn "Health check failed - service may still be starting"
    }
}

# 显示部署信息
function Show-DeploymentInfo {
    Write-Header "🎉 Nginx Manager Deployed Successfully!"

    Write-Host "🌐 Access URLs:" -ForegroundColor Green
    Write-Host "   Web Interface: http://localhost:7000" -ForegroundColor Yellow
    Write-Host "   HTTPS Interface: https://localhost:8443" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "📊 Management Commands:" -ForegroundColor Cyan
    Write-Host "   View status: docker-compose --env-file $CONFIG_FILE ps"
    Write-Host "   View logs: docker-compose --env-file $CONFIG_FILE logs -f"
    Write-Host "   Stop service: docker-compose --env-file $CONFIG_FILE down"
    Write-Host "   Restart: docker-compose --env-file $CONFIG_FILE restart"
    Write-Host ""

    Write-Host "📁 Data Directory:" -ForegroundColor Cyan
    Write-Host "   ./dockernpm-data/" -ForegroundColor Gray
    Write-Host ""

    Write-Host "⚙️  Configuration:" -ForegroundColor Cyan
    Write-Host "   Edit $CONFIG_FILE to change ports and settings" -ForegroundColor Gray
}

# ==========================
# 主函数
# ==========================

function Invoke-Main {
    Write-Header "Nginx Manager One-Click Deploy"

    # 检查Docker环境
    if (-not (Test-DockerEnv)) {
        exit 1
    }

    # 检查镜像
    if (-not (Test-Image)) {
        Write-Host ""
        Write-Info "Pulling Docker image..."
        try {
            docker pull $IMAGE_NAME
            Write-Ok "Image pulled successfully"
        }
        catch {
            Write-Error "Failed to pull image: $_"
            Write-Host "Please check your internet connection and try again." -ForegroundColor Red
            exit 1
        }
    }

    # 初始化配置
    Initialize-Config

    # 创建目录结构
    New-DataDirectories

    # 部署服务
    if (Start-Deployment) {
        # 验证部署
        Test-Deployment

        # 显示信息
        Show-DeploymentInfo
    } else {
        Write-Error "Deployment failed"
        exit 1
    }
}

# 执行主函数
Invoke-Main
