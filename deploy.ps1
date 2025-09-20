# Nginx Manager Deployment Script
# Interactive menu-driven deployment and management tool

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    [Parameter(Mandatory=$false)]
    [switch]$Silent,
    [Parameter(Mandatory=$false)]
    [string]$MenuOption,
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# ==========================
# 配置
# ==========================
$IMAGE_NAME = "docker.io/wtation/nginx-manager:latest"
$CONFIG_FILE = "config.env"
$COMPOSE_FILE = "docker-compose.yml"
$LOCALHOST_ONLY = $false

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

    # 创建或更新配置文件
    if (-not (Test-Path $CONFIG_FILE)) {
        Write-Info "Creating default config.env..."
        $defaultConfig = @"
# Nginx Manager Environment Configuration
# 修改这些变量来改变端口配置
# 只需修改这里，所有相关配置文件都会自动使用这些值

# 外部访问端口 (修改这里来改变端口)
EXTERNAL_HTTP_PORT=7000
EXTERNAL_HTTPS_PORT=8443

# 内部容器端口 (通常不需要修改)
INTERNAL_HTTP_PORT=5000
INTERNAL_HTTPS_PORT=5001

# Nginx代理端口
NGINX_HTTP_PORT=80
NGINX_HTTPS_PORT=443

# 数据目录配置 (修改这里来改变数据存储位置)
DATA_BASE_DIR=./dockernpm-data

# 数据库配置
DATABASE_PATH=/app/data/nginxmanager.db

# 应用环境
ASPNETCORE_ENVIRONMENT=Production

# 本地访问模式设置
# 设置为true时，HTTP端口只绑定到127.0.0.1（localhost），公网无法访问
# 设置为false时，端口绑定到所有网络接口，公网可以访问
LOCALHOST_ONLY=true
"@
        $defaultConfig | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
        Write-Ok "Created $CONFIG_FILE"
    } else {
        Write-Ok "Config file exists"
        # 检查配置文件是否是最新的格式
        $configContent = Get-Content $CONFIG_FILE
        $hasLocalhostSetting = $configContent | Where-Object { $_ -match '^LOCALHOST_ONLY=' }
        $hasDetailedComments = $configContent | Where-Object { $_ -match '本地访问模式设置' }

        if (-not $hasLocalhostSetting -or -not $hasDetailedComments) {
            Write-Info "Updating config.env to latest format..."
            # 备份现有配置
            $backupConfig = @{}
            foreach ($line in $configContent) {
                if ($line -match '^([^#][^=]+)=(.*)$') {
                    $backupConfig[$matches[1].Trim()] = $matches[2].Trim()
                }
            }

            # 获取现有配置值，如果不存在则使用默认值
            $externalHttpPort = if ($backupConfig.ContainsKey('EXTERNAL_HTTP_PORT')) { $backupConfig['EXTERNAL_HTTP_PORT'] } else { '7000' }
            $externalHttpsPort = if ($backupConfig.ContainsKey('EXTERNAL_HTTPS_PORT')) { $backupConfig['EXTERNAL_HTTPS_PORT'] } else { '8443' }
            $internalHttpPort = if ($backupConfig.ContainsKey('INTERNAL_HTTP_PORT')) { $backupConfig['INTERNAL_HTTP_PORT'] } else { '5000' }
            $internalHttpsPort = if ($backupConfig.ContainsKey('INTERNAL_HTTPS_PORT')) { $backupConfig['INTERNAL_HTTPS_PORT'] } else { '5001' }
            $nginxHttpPort = if ($backupConfig.ContainsKey('NGINX_HTTP_PORT')) { $backupConfig['NGINX_HTTP_PORT'] } else { '80' }
            $nginxHttpsPort = if ($backupConfig.ContainsKey('NGINX_HTTPS_PORT')) { $backupConfig['NGINX_HTTPS_PORT'] } else { '443' }
            $dataBaseDir = if ($backupConfig.ContainsKey('DATA_BASE_DIR')) { $backupConfig['DATA_BASE_DIR'] } else { './dockernpm-data' }
            $databasePath = if ($backupConfig.ContainsKey('DATABASE_PATH')) { $backupConfig['DATABASE_PATH'] } else { '/app/data/nginxmanager.db' }
            $aspnetcoreEnvironment = if ($backupConfig.ContainsKey('ASPNETCORE_ENVIRONMENT')) { $backupConfig['ASPNETCORE_ENVIRONMENT'] } else { 'Production' }
            $localhostOnly = if ($backupConfig.ContainsKey('LOCALHOST_ONLY')) { $backupConfig['LOCALHOST_ONLY'] } else { 'true' }

            # 创建新的完整配置，保留现有设置
            $updatedConfig = @"
# Nginx Manager Environment Configuration
# 修改这些变量来改变端口配置
# 只需修改这里，所有相关配置文件都会自动使用这些值

# 外部访问端口 (修改这里来改变端口)
EXTERNAL_HTTP_PORT=$externalHttpPort
EXTERNAL_HTTPS_PORT=$externalHttpsPort

# 内部容器端口 (通常不需要修改)
INTERNAL_HTTP_PORT=$internalHttpPort
INTERNAL_HTTPS_PORT=$internalHttpsPort

# Nginx代理端口
NGINX_HTTP_PORT=$nginxHttpPort
NGINX_HTTPS_PORT=$nginxHttpsPort

# 数据目录配置 (修改这里来改变数据存储位置)
DATA_BASE_DIR=$dataBaseDir

# 数据库配置
DATABASE_PATH=$databasePath

# 应用环境
ASPNETCORE_ENVIRONMENT=$aspnetcoreEnvironment

# 本地访问模式设置
# 设置为true时，HTTP端口只绑定到127.0.0.1（localhost），公网无法访问
# 设置为false时，端口绑定到所有网络接口，公网可以访问
LOCALHOST_ONLY=$localhostOnly
"@
            $updatedConfig | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
            Write-Ok "Updated config.env to latest format"
        }
    }
}

# 自动创建目录结构
function New-DataDirectories {
    Write-Info "Creating data directory structure..."

    # Get data directory from config, use default if not set
    $dataBaseDir = if ($script:DATA_BASE_DIR) { $script:DATA_BASE_DIR } else { "./dockernpm-data" }

    $directories = @(
        $dataBaseDir,
        "$dataBaseDir/data",
        "$dataBaseDir/nginx-instances",
        "$dataBaseDir/ssl",
        "$dataBaseDir/logs",
        "$dataBaseDir/www",
        "$dataBaseDir/temp"
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

# 检查端口占用
function Test-Ports {
    Write-Info "Checking port availability..."

    # 读取配置文件中的端口
    if (Test-Path $CONFIG_FILE) {
        $configContent = Get-Content $CONFIG_FILE | Where-Object { $_ -match '^[^#]' -and $_ -match '=' }
        foreach ($line in $configContent) {
            $key, $value = $line -split '=', 2
            $key = $key.Trim()
            $value = $value.Trim()
            if ($value -match '^"(.*)"$') { $value = $matches[1] }
            if ($value -match "^'(.*)'$") { $value = $matches[1] }
            Set-Variable -Name $key -Value $value -Scope Script
        }
    }

    # 设置脚本级别的LOCALHOST_ONLY变量
    if ($script:LOCALHOST_ONLY) {
        $script:LOCALHOST_ONLY = [System.Convert]::ToBoolean($script:LOCALHOST_ONLY)
    } else {
        $script:LOCALHOST_ONLY = $false
    }

    # 设置默认值
    if (-not $script:EXTERNAL_HTTP_PORT) { $script:EXTERNAL_HTTP_PORT = "7000" }
    if (-not $script:EXTERNAL_HTTPS_PORT) { $script:EXTERNAL_HTTPS_PORT = "8443" }
    if (-not $script:NGINX_HTTP_PORT) { $script:NGINX_HTTP_PORT = "80" }
    if (-not $script:NGINX_HTTPS_PORT) { $script:NGINX_HTTPS_PORT = "443" }

    $ports = @($script:EXTERNAL_HTTP_PORT, $script:EXTERNAL_HTTPS_PORT, $script:NGINX_HTTP_PORT, $script:NGINX_HTTPS_PORT)
    $conflictFound = $false

    foreach ($port in $ports) {
        try {
            if ($script:LOCALHOST_ONLY) {
                # 检查localhost特定端口
                $connection = Test-NetConnection -ComputerName 127.0.0.1 -Port $port -WarningAction SilentlyContinue
                if ($connection.TcpTestSucceeded) {
                    Write-Warn "Local port 127.0.0.1:${port} is already in use"
                    Write-Host "Process using port ${port}:" -ForegroundColor Yellow
                    try {
                        $processInfo = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $port -ErrorAction Stop | Select-Object -First 1
                        if ($processInfo) {
                            $process = Get-Process -Id $processInfo.OwningProcess -ErrorAction SilentlyContinue
                            if ($process) {
                                Write-Host "  Process: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Gray
                            }
                        }
                    } catch {
                        Write-Host "  Unable to determine process information" -ForegroundColor Gray
                    }
                    $conflictFound = $true
                } else {
                    Write-Host "  ✓ Local port 127.0.0.1:${port} is available" -ForegroundColor Green
                }
            } else {
                # 检查所有接口的端口
                $connection = Test-NetConnection -ComputerName localhost -Port $port -WarningAction SilentlyContinue
                if ($connection.TcpTestSucceeded) {
                    Write-Warn "Port ${port} is already in use"
                    Write-Host "Process using port ${port}:" -ForegroundColor Yellow
                    try {
                        $processInfo = Get-NetTCPConnection -LocalPort $port -ErrorAction Stop | Select-Object -First 1
                        if ($processInfo) {
                            $process = Get-Process -Id $processInfo.OwningProcess -ErrorAction SilentlyContinue
                            if ($process) {
                                Write-Host "  Process: $($process.ProcessName) (PID: $($process.Id))" -ForegroundColor Gray
                            }
                        }
                    } catch {
                        Write-Host "  Unable to determine process information" -ForegroundColor Gray
                    }
                    $conflictFound = $true
                } else {
                    Write-Host "  ✓ Port ${port} is available" -ForegroundColor Green
                }
            }
        }
        catch {
            if ($script:LOCALHOST_ONLY) {
                Write-Host "  ✓ Local port 127.0.0.1:${port} is available" -ForegroundColor Green
            } else {
                Write-Host "  ✓ Port ${port} is available" -ForegroundColor Green
            }
        }
    }

    if ($conflictFound) {
        Write-Host ""
        Write-Warn "Port conflicts detected!"
        Write-Host ""
        Write-Host "Solutions:" -ForegroundColor Cyan
        Write-Host "1. Modify port configuration in $CONFIG_FILE"
        Write-Host "2. Stop the processes using these ports"
        Write-Host ""
        Write-Host "Example port changes:" -ForegroundColor Yellow
        Write-Host "  EXTERNAL_HTTP_PORT=7001"
        Write-Host "  EXTERNAL_HTTPS_PORT=8444"
        Write-Host ""

        $continue = Read-Host "Do you want to continue anyway? (y/N)"
        if ($continue -notmatch "^[Yy]$") {
            return $false
        }
    } else {
        Write-Ok "All ports are available"
    }

    return $true
}

# 生成Docker Compose配置文件
function New-ComposeFile {
    Write-Info "Generating Docker Compose configuration..."

    # 读取配置
    $externalHttpPort = if ($script:EXTERNAL_HTTP_PORT) { $script:EXTERNAL_HTTP_PORT } else { "7000" }
    $externalHttpsPort = if ($script:EXTERNAL_HTTPS_PORT) { $script:EXTERNAL_HTTPS_PORT } else { "8443" }
    $internalHttpPort = if ($script:INTERNAL_HTTP_PORT) { $script:INTERNAL_HTTP_PORT } else { "5000" }
    $internalHttpsPort = if ($script:INTERNAL_HTTPS_PORT) { $script:INTERNAL_HTTPS_PORT } else { "5001" }
    $nginxHttpPort = if ($script:NGINX_HTTP_PORT) { $script:NGINX_HTTP_PORT } else { "80" }
    $nginxHttpsPort = if ($script:NGINX_HTTPS_PORT) { $script:NGINX_HTTPS_PORT } else { "443" }
    $dataBaseDir = if ($script:DATA_BASE_DIR) { $script:DATA_BASE_DIR } else { "./dockernpm-data" }
    $databasePath = if ($script:DATABASE_PATH) { $script:DATABASE_PATH } else { "/app/data/nginxmanager.db" }
    $aspnetcoreEnvironment = if ($script:ASPNETCORE_ENVIRONMENT) { $script:ASPNETCORE_ENVIRONMENT } else { "Production" }
    $localhostOnly = $script:LOCALHOST_ONLY

    # 根据LOCALHOST_ONLY设置确定端口绑定前缀
    if ($localhostOnly) {
        $httpPortBinding = "127.0.0.1:${externalHttpPort}:${internalHttpPort}"
        $httpsPortBinding = "127.0.0.1:${externalHttpsPort}:${internalHttpsPort}"
        $nginxHttpBinding = "127.0.0.1:${nginxHttpPort}:80"
        $nginxHttpsBinding = "127.0.0.1:${nginxHttpsPort}:443"
        $bindingMode = "Local binding (127.0.0.1)"
    } else {
        $httpPortBinding = "${externalHttpPort}:${internalHttpPort}"
        $httpsPortBinding = "${externalHttpsPort}:${internalHttpsPort}"
        $nginxHttpBinding = "${nginxHttpPort}:80"
        $nginxHttpsBinding = "${nginxHttpsPort}:443"
        $bindingMode = "Public binding (0.0.0.0)"
    }

    # 生成docker-compose.yml
    $composeContent = @"
version: '3.8'

services:
  nginx-manager:
    image: ${IMAGE_NAME}
    container_name: nginx-manager
    restart: unless-stopped

    # Port mapping (${bindingMode})
    ports:
      - "${httpPortBinding}"    # HTTP port
      - "${httpsPortBinding}"  # HTTPS port
      - "${nginxHttpBinding}"   # Nginx HTTP port
      - "${nginxHttpsBinding}"  # Nginx HTTPS port

    environment:
      - ASPNETCORE_ENVIRONMENT=${aspnetcoreEnvironment}
      - ASPNETCORE_URLS=http://+:${internalHttpPort};https://+:${internalHttpsPort}
      - DOTNET_RUNNING_IN_CONTAINER=true
      - ConnectionStrings__Default=Data Source=${databasePath}
      - NginxManager__DefaultDataDir=/app/data
      - NginxManager__DefaultNginxDir=/app/nginx-instances
      - NginxManager__DefaultSslDir=/app/ssl
      - NginxManager__DefaultLogDir=/app/logs
      - NginxManager__DefaultWebRootDir=/var/www/html

    volumes:
      - ${dataBaseDir}/data:/app/data:rw
      - ${dataBaseDir}/nginx-instances:/app/nginx-instances:rw
      - ${dataBaseDir}/ssl:/app/ssl:rw
      - ${dataBaseDir}/logs:/app/logs:rw
      - ${dataBaseDir}/www:/var/www/html:rw
      - ${dataBaseDir}/temp:/tmp:rw

    networks:
      - nginx-network

    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${internalHttpPort}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 256M

networks:
  nginx-network:
    driver: bridge
"@

    $composeContent | Out-File -FilePath $COMPOSE_FILE -Encoding UTF8
    Write-Ok "Docker Compose configuration generated (${bindingMode})"
}

# 部署服务
function Start-Deployment {
    Write-Header "🚀 Starting Nginx Manager Deployment"

    # 生成Docker Compose配置
    New-ComposeFile

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
            Write-Host ""
            Write-Host "Possible solutions:" -ForegroundColor Cyan
            Write-Host "1. Check if ports are being used by other services"
            Write-Host "2. Modify port configuration in $CONFIG_FILE"
            Write-Host "3. Ensure Docker service is running"
            Write-Host "4. Try: docker-compose --env-file $CONFIG_FILE down"
            Write-Host ""
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
        $healthPort = if ($script:EXTERNAL_HTTP_PORT) { $script:EXTERNAL_HTTP_PORT } else { "7000" }
        $response = Invoke-WebRequest -Uri "http://localhost:$healthPort/health" -TimeoutSec 10 -ErrorAction Stop
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

    # 根据绑定模式显示不同的访问地址
    if ($script:LOCALHOST_ONLY) {
        Write-Host "🔒 Local Access URLs (127.0.0.1/localhost only):" -ForegroundColor Green
        Write-Host "   Web Interface: http://127.0.0.1:$($script:EXTERNAL_HTTP_PORT) or http://localhost:$($script:EXTERNAL_HTTP_PORT)" -ForegroundColor Yellow
        Write-Host "   HTTPS Interface: https://127.0.0.1:$($script:EXTERNAL_HTTPS_PORT) or https://localhost:$($script:EXTERNAL_HTTPS_PORT)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "⚠️  Note: Ports are bound to localhost only, public access is not available" -ForegroundColor Yellow
    } else {
        Write-Host "🌐 Access URLs:" -ForegroundColor Green
        Write-Host "   Web Interface: http://localhost:$($script:EXTERNAL_HTTP_PORT)" -ForegroundColor Yellow
        Write-Host "   HTTPS Interface: https://localhost:$($script:EXTERNAL_HTTPS_PORT)" -ForegroundColor Yellow
        Write-Host "   Public Access: http://<server-ip>:$($script:EXTERNAL_HTTP_PORT)" -ForegroundColor Yellow
    }
    Write-Host ""

    Write-Host "📊 Management Commands:" -ForegroundColor Cyan
    Write-Host "   View status: docker-compose --env-file $CONFIG_FILE ps"
    Write-Host "   View logs: docker-compose --env-file $CONFIG_FILE logs -f"
    Write-Host "   Stop service: docker-compose --env-file $CONFIG_FILE down"
    Write-Host "   Restart: docker-compose --env-file $CONFIG_FILE restart"
    Write-Host ""

    Write-Host "📁 Data Directory:" -ForegroundColor Cyan
    $dataDir = if ($script:DATA_BASE_DIR) { $script:DATA_BASE_DIR } else { "./dockernpm-data" }
    Write-Host "   $dataDir/" -ForegroundColor Gray
    Write-Host ""

    Write-Host "⚙️  Configuration:" -ForegroundColor Cyan
    Write-Host "   Edit $CONFIG_FILE to change ports and settings" -ForegroundColor Gray
    if (-not $script:LOCALHOST_ONLY) {
        Write-Host "   Set LOCALHOST_ONLY=true to restrict to local access only" -ForegroundColor Gray
    }
}

# ==========================
# Menu System Functions
# ==========================

function Show-MainMenu {
    Write-Header "Nginx Manager Deployment & Management Tool"

    Write-Host "Please select an option:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Default One-Click Installation" -ForegroundColor Yellow
    Write-Host "2. Custom Installation (Configure ports, paths, etc.)" -ForegroundColor Yellow
    Write-Host "3. Maintenance & Management" -ForegroundColor Yellow
    Write-Host "4. Restore to Default Configuration" -ForegroundColor Yellow
    Write-Host "5. Exit" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Current Status:" -ForegroundColor Cyan
    Show-ServiceStatus
    Write-Host ""
}

function Show-ServiceStatus {
    try {
        $containers = docker-compose --env-file config.env ps --format "table {{.Name}}\t{{.Status}}" 2>$null
        if ($containers) {
            Write-Host "Services Status:" -ForegroundColor Green
            Write-Host $containers
        } else {
            Write-Host "No services running" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "Unable to check service status" -ForegroundColor Gray
    }
}

function Show-MaintenanceMenu {
    Write-Header "Maintenance & Management"

    Write-Host "Please select a maintenance option:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Start Services" -ForegroundColor Yellow
    Write-Host "2. Stop Services" -ForegroundColor Yellow
    Write-Host "3. Restart Services" -ForegroundColor Yellow
    Write-Host "4. Update Docker Image" -ForegroundColor Yellow
    Write-Host "5. View Service Logs" -ForegroundColor Yellow
    Write-Host "6. View Container Status" -ForegroundColor Yellow
    Write-Host "7. Clean Up (Remove stopped containers)" -ForegroundColor Yellow
    Write-Host "8. Backup Configuration" -ForegroundColor Yellow
    Write-Host "9. Back to Main Menu" -ForegroundColor Yellow
    Write-Host ""
}

function Invoke-DefaultInstallation {
    Write-Header "Default One-Click Installation"

    # 检查Docker环境
    if (-not (Test-DockerEnv)) {
        return $false
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
            return $false
        }
    }

    # 初始化配置
    Initialize-Config

    # 创建目录结构
    New-DataDirectories

    # 检查端口占用
    if (-not (Test-Ports)) {
        return $false
    }

    # 部署服务
    if (Start-Deployment) {
        # 验证部署
        Test-Deployment

        # 显示信息
        Show-DeploymentInfo
        return $true
    } else {
        Write-Error "Deployment failed"
        return $false
    }
}

function Invoke-CustomInstallation {
    Write-Header "Custom Installation"

    Write-Host "This will guide you through configuring Nginx Manager with custom settings." -ForegroundColor Cyan
    Write-Host ""

    # 获取用户配置
    $customConfig = Get-CustomConfiguration

    if (-not $customConfig) {
        Write-Warn "Installation cancelled by user"
        return $false
    }

    # 应用自定义配置
    Apply-CustomConfiguration $customConfig

    # 执行安装
    return Invoke-DefaultInstallation
}

function Get-CustomConfiguration {
    $config = @{
        HttpPort = $null
        HttpsPort = $null
        NginxHttpPort = $null
        NginxHttpsPort = $null
        DataDir = $null
        LocalhostOnly = $null
    }

    Write-Host "Enter custom configuration (press Enter for default values):" -ForegroundColor Cyan
    Write-Host ""

    # HTTP Port
    do {
        $input = Read-Host "HTTP Port for web interface (default: 7000)"
        if ([string]::IsNullOrWhiteSpace($input)) {
            $config.HttpPort = "7000"
            break
        }
        if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le 65535) {
            $config.HttpPort = $input
            break
        } else {
            Write-Warn "Invalid port number. Please enter a number between 1-65535."
        }
    } while ($true)

    # HTTPS Port
    do {
        $input = Read-Host "HTTPS Port for web interface (default: 8443)"
        if ([string]::IsNullOrWhiteSpace($input)) {
            $config.HttpsPort = "8443"
            break
        }
        if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le 65535) {
            $config.HttpsPort = $input
            break
        } else {
            Write-Warn "Invalid port number. Please enter a number between 1-65535."
        }
    } while ($true)

    # Nginx HTTP Port
    do {
        $input = Read-Host "Nginx HTTP Port (default: 80)"
        if ([string]::IsNullOrWhiteSpace($input)) {
            $config.NginxHttpPort = "80"
            break
        }
        if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le 65535) {
            $config.NginxHttpPort = $input
            break
        } else {
            Write-Warn "Invalid port number. Please enter a number between 1-65535."
        }
    } while ($true)

    # Nginx HTTPS Port
    do {
        $input = Read-Host "Nginx HTTPS Port (default: 443)"
        if ([string]::IsNullOrWhiteSpace($input)) {
            $config.NginxHttpsPort = "443"
            break
        }
        if ($input -match '^\d+$' -and [int]$input -ge 1 -and [int]$input -le 65535) {
            $config.NginxHttpsPort = $input
            break
        } else {
            Write-Warn "Invalid port number. Please enter a number between 1-65535."
        }
    } while ($true)

    # Data Directory
    $input = Read-Host "Data directory path (default: ./dockernpm-data)"
    if ([string]::IsNullOrWhiteSpace($input)) {
        $config.DataDir = "./dockernpm-data"
    } else {
        $config.DataDir = $input
    }

    # Localhost Only
    do {
        $input = Read-Host "Bind to localhost only? (y/n, default: y for security)"
        if ([string]::IsNullOrWhiteSpace($input)) {
            $config.LocalhostOnly = "true"
            break
        }
        if ($input -match '^(y|yes)$') {
            $config.LocalhostOnly = "true"
            break
        }
        if ($input -match '^(n|no)$') {
            $config.LocalhostOnly = "false"
            break
        }
        Write-Warn "Please enter 'y' for yes or 'n' for no."
    } while ($true)

    # Confirm configuration
    Write-Host ""
    Write-Host "Configuration Summary:" -ForegroundColor Cyan
    Write-Host "HTTP Port: $($config.HttpPort)"
    Write-Host "HTTPS Port: $($config.HttpsPort)"
    Write-Host "Nginx HTTP Port: $($config.NginxHttpPort)"
    Write-Host "Nginx HTTPS Port: $($config.NginxHttpsPort)"
    Write-Host "Data Directory: $($config.DataDir)"
    Write-Host "Localhost Only: $($config.LocalhostOnly)"
    Write-Host ""

    $confirm = Read-Host "Proceed with this configuration? (y/N)"
    if ($confirm -match '^(y|yes)$') {
        return $config
    } else {
        return $null
    }
}

function Apply-CustomConfiguration {
    param([hashtable]$config)

    Write-Info "Applying custom configuration..."

    # Update config.env
    $configContent = @"
# Nginx Manager Environment Configuration
# 修改这些变量来改变端口配置
# 只需修改这里，所有相关配置文件都会自动使用这些值

# 外部访问端口 (修改这里来改变端口)
EXTERNAL_HTTP_PORT=$($config.HttpPort)
EXTERNAL_HTTPS_PORT=$($config.HttpsPort)

# 内部容器端口 (通常不需要修改)
INTERNAL_HTTP_PORT=5000
INTERNAL_HTTPS_PORT=5001

# Nginx代理端口
NGINX_HTTP_PORT=$($config.NginxHttpPort)
NGINX_HTTPS_PORT=$($config.NginxHttpsPort)

# 数据目录配置 (修改这里来改变数据存储位置)
DATA_BASE_DIR=$($config.DataDir)

# 数据库配置
DATABASE_PATH=/app/data/nginxmanager.db

# 应用环境
ASPNETCORE_ENVIRONMENT=Production

# 本地访问模式设置
# 设置为true时，HTTP端口只绑定到127.0.0.1（localhost），公网无法访问
# 设置为false时，端口绑定到所有网络接口，公网可以访问
LOCALHOST_ONLY=$($config.LocalhostOnly)
"@

    $configContent | Out-File -FilePath $CONFIG_FILE -Encoding UTF8
    Write-Ok "Custom configuration applied"
}

function Invoke-MaintenanceMenu {
    do {
        Show-MaintenanceMenu
        $choice = Read-Host "Enter your choice (1-9)"

        switch ($choice) {
            "1" { Invoke-StartServices }
            "2" { Invoke-StopServices }
            "3" { Invoke-RestartServices }
            "4" { Invoke-UpdateImage }
            "5" { Invoke-ViewLogs }
            "6" { Invoke-ViewStatus }
            "7" { Invoke-Cleanup }
            "8" { Invoke-BackupConfig }
            "9" { return }
            default {
                Write-Warn "Invalid choice. Please enter 1-9."
                Start-Sleep -Seconds 2
            }
        }

        if ($choice -ne "9") {
            Write-Host ""
            Read-Host "Press Enter to continue"
        }
    } while ($choice -ne "9")
}

function Invoke-StartServices {
    Write-Header "Starting Services"
    try {
        docker-compose --env-file config.env up -d
        Write-Ok "Services started successfully"
        Show-ServiceStatus
    }
    catch {
        Write-Error "Failed to start services: $_"
    }
}

function Invoke-StopServices {
    Write-Header "Stopping Services"
    try {
        docker-compose --env-file config.env down
        Write-Ok "Services stopped successfully"
    }
    catch {
        Write-Error "Failed to stop services: $_"
    }
}

function Invoke-RestartServices {
    Write-Header "Restarting Services"
    try {
        docker-compose --env-file config.env restart
        Write-Ok "Services restarted successfully"
        Show-ServiceStatus
    }
    catch {
        Write-Error "Failed to restart services: $_"
    }
}

function Invoke-UpdateImage {
    Write-Header "Updating Docker Image"
    try {
        Write-Info "Pulling latest image..."
        docker pull $IMAGE_NAME
        Write-Ok "Image updated successfully"

        Write-Info "Restarting services with new image..."
        docker-compose --env-file config.env up -d
        Write-Ok "Services updated and restarted"
        Show-ServiceStatus
    }
    catch {
        Write-Error "Failed to update image: $_"
    }
}

function Invoke-ViewLogs {
    Write-Header "Service Logs"
    Write-Host "Choose log option:" -ForegroundColor Cyan
    Write-Host "1. View last 50 lines" -ForegroundColor Yellow
    Write-Host "2. Follow logs (Ctrl+C to exit)" -ForegroundColor Yellow
    Write-Host ""

    $logChoice = Read-Host "Enter choice (1-2)"
    switch ($logChoice) {
        "1" {
            try {
                docker-compose --env-file config.env logs --tail=50
            }
            catch {
                Write-Error "Failed to view logs: $_"
            }
        }
        "2" {
            Write-Host "Press Ctrl+C to exit log view" -ForegroundColor Yellow
            try {
                docker-compose --env-file config.env logs -f
            }
            catch {
                Write-Error "Failed to follow logs: $_"
            }
        }
        default {
            Write-Warn "Invalid choice"
        }
    }
}

function Invoke-ViewStatus {
    Write-Header "Container Status"
    try {
        $status = docker-compose --env-file config.env ps
        Write-Host $status
    }
    catch {
        Write-Error "Failed to get status: $_"
    }
}

function Invoke-Cleanup {
    Write-Header "Cleaning Up"
    try {
        Write-Info "Removing stopped containers..."
        docker container prune -f

        Write-Info "Removing unused images..."
        docker image prune -f

        Write-Info "Removing unused volumes..."
        docker volume prune -f

        Write-Ok "Cleanup completed"
    }
    catch {
        Write-Error "Cleanup failed: $_"
    }
}

function Invoke-BackupConfig {
    Write-Header "Backup Configuration"
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = "backup_$timestamp"

        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

        if (Test-Path config.env) {
            Copy-Item config.env "$backupDir\"
        }
        if (Test-Path docker-compose.yml) {
            Copy-Item docker-compose.yml "$backupDir\"
        }
        if (Test-Path "dockernpm-data") {
            Copy-Item "dockernpm-data" "$backupDir\" -Recurse
        }

        Write-Ok "Configuration backed up to: $backupDir"
    }
    catch {
        Write-Error "Backup failed: $_"
    }
}

function Invoke-RestoreDefaults {
    Write-Header "Restore to Default Configuration"

    Write-Warn "This will restore Nginx Manager to default configuration."
    Write-Warn "All custom settings will be lost."
    Write-Host ""

    $confirm = Read-Host "Are you sure you want to continue? (yes/no)"
    if ($confirm -ne "yes") {
        Write-Info "Operation cancelled"
        return
    }

    try {
        # Stop services
        Write-Info "Stopping services..."
        docker-compose --env-file config.env down 2>$null | Out-Null

        # Remove containers and volumes
        Write-Info "Removing containers and volumes..."
        docker-compose --env-file config.env down -v 2>$null | Out-Null

        # Remove data directory
        if (Test-Path "dockernpm-data") {
            Write-Info "Removing data directory..."
            Remove-Item "dockernpm-data" -Recurse -Force
        }

        # Remove config files
        if (Test-Path config.env) {
            Write-Info "Removing configuration files..."
            Remove-Item config.env -Force
        }
        if (Test-Path docker-compose.yml) {
            Remove-Item docker-compose.yml -Force
        }

        Write-Ok "Restoration completed. Run the script again to perform a fresh installation."
    }
    catch {
        Write-Error "Restoration failed: $_"
    }
}

# ==========================
# 主函数
# ==========================

function Invoke-Main {
    # Check if running in silent mode or with specific option
    if ($Silent) {
        return Invoke-DefaultInstallation
    }

    if ($MenuOption) {
        switch ($MenuOption) {
            "1" { return Invoke-DefaultInstallation }
            "2" { return Invoke-CustomInstallation }
            "3" { Invoke-MaintenanceMenu; return $true }
            "4" { Invoke-RestoreDefaults; return $true }
            default {
                Write-Error "Invalid menu option: $MenuOption"
                return $false
            }
        }
    }

    # Interactive menu mode
    do {
        Show-MainMenu
        $choice = Read-Host "Enter your choice (1-5)"

        switch ($choice) {
            "1" {
                $result = Invoke-DefaultInstallation
                if ($result) {
                    Write-Host ""
                    Read-Host "Press Enter to return to main menu"
                }
            }
            "2" {
                $result = Invoke-CustomInstallation
                if ($result) {
                    Write-Host ""
                    Read-Host "Press Enter to return to main menu"
                }
            }
            "3" {
                Invoke-MaintenanceMenu
            }
            "4" {
                Invoke-RestoreDefaults
                Write-Host ""
                Read-Host "Press Enter to return to main menu"
            }
            "5" {
                Write-Host "Goodbye!" -ForegroundColor Green
                return $true
            }
            default {
                Write-Warn "Invalid choice. Please enter 1-5."
                Start-Sleep -Seconds 2
            }
        }
    } while ($choice -ne "5")
}

# ==========================
# Script Execution
# ==========================

# Show help if requested
if ($Help -or ($args -contains "--help") -or ($args -contains "-h")) {
    Write-Host "Nginx Manager Deployment Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  .\deploy.ps1                    - Interactive menu mode"
    Write-Host "  .\deploy.ps1 -MenuOption 1      - Default installation"
    Write-Host "  .\deploy.ps1 -MenuOption 2      - Custom installation"
    Write-Host "  .\deploy.ps1 -MenuOption 3      - Maintenance menu"
    Write-Host "  .\deploy.ps1 -MenuOption 4      - Restore defaults"
    Write-Host "  .\deploy.ps1 -Silent            - Silent default installation"
    Write-Host "  .\deploy.ps1 -Force             - Force mode (override existing)"
    Write-Host "  .\deploy.ps1 -Help              - Show this help message"
    Write-Host ""
    Write-Host "Menu Options:" -ForegroundColor Yellow
    Write-Host "  1. Default One-Click Installation"
    Write-Host "  2. Custom Installation (configure ports, paths, etc.)"
    Write-Host "  3. Maintenance & Management"
    Write-Host "  4. Restore to Default Configuration"
    Write-Host "  5. Exit"
    Write-Host ""
    exit 0
}

# Execute main function
Invoke-Main
