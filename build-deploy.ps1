# Nginx Manager Build & Deploy Script
# 编译源码、构建镜像并部署的一体化脚本

param(
    [Parameter(Mandatory=$false)]
    [switch]$Force,
    [Parameter(Mandatory=$false)]
    [switch]$Silent,
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    [Parameter(Mandatory=$false)]
    [switch]$SkipDeploy,
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = "latest",
    [Parameter(Mandatory=$false)]
    [switch]$Push,
    [Parameter(Mandatory=$false)]
    [string]$Registry = "docker.io",
    [Parameter(Mandatory=$false)]
    [string]$Username,
    [Parameter(Mandatory=$false)]
    [string]$ImageName = "nginx-manager",
    [Parameter(Mandatory=$false)]
    [switch]$NoCache,
    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# ==========================
# 配置
# ==========================
$PROJECT_ROOT = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$NginxManager_DIR = Join-Path $PROJECT_ROOT "webmng/NginxManager"
$DOCKERFILE_DIR = Join-Path $PROJECT_ROOT "webmng/deploy"
$BUILD_SCRIPT_DIR = Join-Path $PROJECT_ROOT "webmng/deploy/compose"

# 构建完整的镜像名称
function Get-FullImageName {
    param(
        [string]$Registry,
        [string]$Username,
        [string]$ImageName
    )

    if ($Registry -eq "docker.io" -and $Username) {
        return "$Registry/$Username/$ImageName"
    } elseif ($Registry -ne "docker.io") {
        return "$Registry/$ImageName"
    } else {
        return $ImageName
    }
}

# 获取完整镜像名称和目标镜像
$FULL_IMAGE_NAME = Get-FullImageName -Registry $Registry -Username $Username -ImageName $ImageName
$TARGET_IMAGE = if ($ImageTag -eq "latest") {
    $FULL_IMAGE_NAME
} else {
    "$FULL_IMAGE_NAME`:$ImageTag"
}

# ==========================
# UI Helpers
# ==========================
$RED = "Red"
$GREEN = "Green"
$YELLOW = "Yellow"
$CYAN = "Cyan"
$GRAY = "Gray"

function Write-Info {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "ℹ $Message" -ForegroundColor $CYAN
    }
}

function Write-Ok {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "✓ $Message" -ForegroundColor $GREEN
    }
}

function Write-Warn {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "! $Message" -ForegroundColor $YELLOW
    }
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $RED
}

function Write-Header {
    param([string]$Message)
    if (-not $Silent) {
        Write-Host "============================================" -ForegroundColor $CYAN
        Write-Host "$Message" -ForegroundColor $CYAN
        Write-Host "============================================" -ForegroundColor $CYAN
    }
}

# ==========================
# 环境检查
# ==========================

function Test-Environment {
    Write-Info "Checking environment..."

    # 检查 .NET SDK
    try {
        $dotnetVersion = dotnet --version 2>$null
        Write-Ok ".NET SDK: $dotnetVersion"
    }
    catch {
        Write-Error ".NET SDK not found. Please install .NET 9.0 SDK."
        Write-Host "Download: https://dotnet.microsoft.com/download/dotnet/9.0"
        exit 1
    }

    # 检查 Docker
    try {
        $dockerVersion = docker --version 2>$null
        Write-Ok "Docker: $dockerVersion"
    }
    catch {
        Write-Error "Docker not found. Please install Docker."
        exit 1
    }

    try {
        docker info 2>$null | Out-Null
        Write-Ok "Docker daemon is running"
    }
    catch {
        Write-Error "Docker daemon is not running. Please start Docker."
        exit 1
    }

    # 检查项目文件
    if (-not (Test-Path (Join-Path $NginxManager_DIR "NginxManager.csproj"))) {
        Write-Error "Project file not found: NginxManager.csproj"
        exit 1
    }
    Write-Ok "Project files found"
}

# ==========================
# 构建阶段
# ==========================

function Invoke-BuildPhase {
    if ($SkipBuild) {
        Write-Info "Skipping build phase as requested"
        return
    }

    Write-Header "🔨 Build Phase"

    # 使用现有的构建脚本
    $buildScript = Join-Path $BUILD_SCRIPT_DIR "build-image.ps1"

    if (-not (Test-Path $buildScript)) {
        Write-Error "Build script not found: $buildScript"
        Write-Host "Please ensure build-image.ps1 exists in the compose directory"
        exit 1
    }

    # 构建参数
    $buildArgs = @(
        "-Registry", $Registry,
        "-ImageName", $ImageName,
        "-Tag", $ImageTag
    )

    if ($Username) {
        $buildArgs += "-Username", $Username
    }

    if ($Push) {
        $buildArgs += "-Push"
    }

    if ($NoCache) {
        $buildArgs += "-NoCache"
    }

    if ($Force) {
        $buildArgs += "-Force"
    }

    Write-Info "Building image: $TARGET_IMAGE"
    Write-Host "Command: .\build-image.ps1 $($buildArgs -join ' ')" -ForegroundColor Gray

    try {
        Push-Location $BUILD_SCRIPT_DIR
        & $buildScript @buildArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Build failed"
            exit 1
        }
    }
    catch {
        Write-Error "Build failed: $_"
        exit 1
    }
    finally {
        Pop-Location
    }

    Write-Ok "Build phase completed successfully"
}

# ==========================
# 部署阶段
# ==========================

function Invoke-DeployPhase {
    if ($SkipDeploy) {
        Write-Info "Skipping deploy phase as requested"
        return
    }

    Write-Header "🚀 Deploy Phase"

    # 使用现有的部署脚本
    $deployScript = Join-Path $PSScriptRoot "deploy.ps1"

    if (-not (Test-Path $deployScript)) {
        Write-Error "Deploy script not found: $deployScript"
        exit 1
    }

    # 部署参数
    $deployArgs = @()

    if ($Force) {
        $deployArgs += "-Force"
    }

    if ($Silent) {
        $deployArgs += "-Silent"
    }

    Write-Info "Deploying with built image"
    Write-Host "Command: .\deploy.ps1 $($deployArgs -join ' ')" -ForegroundColor Gray

    try {
        & $deployScript @deployArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Deployment failed"
            exit 1
        }
    }
    catch {
        Write-Error "Deployment failed: $_"
        exit 1
    }

    Write-Ok "Deploy phase completed successfully"
}

# ==========================
# 验证阶段
# ==========================

function Invoke-VerificationPhase {
    Write-Header "🔍 Verification Phase"

    Write-Info "Verifying deployment..."

    # 检查容器状态
    try {
        $containers = docker ps --filter "ancestor=$TARGET_IMAGE" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
        if ($containers -and $containers -notmatch "CONTAINER") {
            Write-Ok "Container is running"
            Write-Host $containers
        } else {
            Write-Warn "No running containers found for image: $TARGET_IMAGE"
        }
    }
    catch {
        Write-Warn "Could not check container status: $_"
    }

    # 测试健康检查
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:7000/health" -TimeoutSec 10 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Ok "Health check passed - service is responding"
        } else {
            Write-Warn "Health check returned status: $($response.StatusCode)"
        }
    }
    catch {
        Write-Warn "Health check failed - service may still be starting"
        Write-Host "Try: docker-compose --env-file config.env logs -f" -ForegroundColor Gray
    }
}

# ==========================
# 主函数
# ==========================

function Invoke-Main {
    Write-Header "Nginx Manager Build & Deploy"

    # 显示配置信息
    if (-not $Silent) {
        Write-Host "Configuration:" -ForegroundColor $CYAN
        Write-Host "  Project Root: $PROJECT_ROOT" -ForegroundColor Gray
        Write-Host "  Target Image: $TARGET_IMAGE" -ForegroundColor Gray
        Write-Host "  Skip Build: $SkipBuild" -ForegroundColor Gray
        Write-Host "  Skip Deploy: $SkipDeploy" -ForegroundColor Gray
        if ($Push) {
            Write-Host "  Push to Registry: Yes ($Registry)" -ForegroundColor Gray
        } else {
            Write-Host "  Push to Registry: No" -ForegroundColor Gray
        }
        Write-Host ""
    }

    # 检查环境
    Test-Environment

    # 构建阶段
    Invoke-BuildPhase

    # 部署阶段
    Invoke-DeployPhase

    # 验证阶段
    if (-not $SkipDeploy) {
        Invoke-VerificationPhase
    }

    Write-Header "🎉 Build & Deploy Complete!"

    if (-not $Silent) {
        Write-Host "Nginx Manager has been successfully built and deployed!" -ForegroundColor Green
        Write-Host ""
        Write-Host "🌐 Access URLs:" -ForegroundColor Cyan
        Write-Host "   Web Interface: http://localhost:7000" -ForegroundColor Yellow
        Write-Host "   HTTPS Interface: https://localhost:8443" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "📊 Management Commands:" -ForegroundColor Cyan
        Write-Host "   View logs: docker-compose --env-file config.env logs -f" -ForegroundColor Gray
        Write-Host "   Stop service: docker-compose --env-file config.env down" -ForegroundColor Gray
        Write-Host ""
        if ($Push) {
            Write-Host "🔗 Image pushed to: $TARGET_IMAGE" -ForegroundColor Green
        }
    }
}

# ==========================
# 帮助信息
# ==========================

if ($Help) {
    Write-Host "Nginx Manager Build & Deploy Script" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "This script compiles the .NET source code, builds a Docker image, and deploys it." -ForegroundColor White
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\build-deploy.ps1 [options]" -ForegroundColor White
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -ImageTag <tag>       Docker image tag (default: latest)" -ForegroundColor White
    Write-Host "  -Registry <registry>  Docker registry (default: docker.io)" -ForegroundColor White
    Write-Host "  -Username <username>  Registry username for push" -ForegroundColor White
    Write-Host "  -ImageName <name>     Docker image name (default: nginx-manager)" -ForegroundColor White
    Write-Host "  -Push                 Push image to registry after build" -ForegroundColor White
    Write-Host "  -NoCache              Build without cache" -ForegroundColor White
    Write-Host "  -Force                Force rebuild and redeploy" -ForegroundColor White
    Write-Host "  -SkipBuild            Skip the build phase (deploy only)" -ForegroundColor White
    Write-Host "  -SkipDeploy           Skip the deploy phase (build only)" -ForegroundColor White
    Write-Host "  -Silent               Silent mode (minimal output)" -ForegroundColor White
    Write-Host "  -Help                 Show this help message" -ForegroundColor White
    Write-Host ""
    Write-Host "EXAMPLES:" -ForegroundColor Cyan
    Write-Host "  .\build-deploy.ps1" -ForegroundColor White
    Write-Host "  .\build-deploy.ps1 -ImageTag v1.0.0 -Push -Username myuser" -ForegroundColor White
    Write-Host "  .\build-deploy.ps1 -SkipBuild -Force  # Deploy existing image" -ForegroundColor White
    Write-Host "  .\build-deploy.ps1 -SkipDeploy        # Build only" -ForegroundColor White
    Write-Host ""
    exit 0
}

# ==========================
# 执行主函数
# ==========================

Invoke-Main
