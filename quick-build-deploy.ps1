# Nginx Manager Quick Build & Deploy Demo
# 演示脚本 - 展示 build-deploy.ps1 的各种用法

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("full", "build-only", "deploy-only", "push-demo", "dev-build")]
    [string]$Demo = "full"
)

# ==========================
# 配置
# ==========================
$SCRIPT_DIR = $PSScriptRoot
$BUILD_DEPLOY_SCRIPT = Join-Path $SCRIPT_DIR "build-deploy.ps1"

# ==========================
# UI Helpers
# ==========================
$CYAN = "Cyan"
$GREEN = "Green"
$YELLOW = "Yellow"
$RED = "Red"

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
# Demo Functions
# ==========================

function Invoke-FullDemo {
    Write-Header "完整演示：编译+构建+部署"

    Write-Host "这个演示将执行完整的流程：" -ForegroundColor Cyan
    Write-Host "1. 编译 .NET 项目" -ForegroundColor White
    Write-Host "2. 构建 Docker 镜像" -ForegroundColor White
    Write-Host "3. 部署到本地环境" -ForegroundColor White
    Write-Host "4. 验证部署结果" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "是否继续？(y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "演示已取消" -ForegroundColor Yellow
        return
    }

    Write-Info "执行完整构建部署流程..."
    & $BUILD_DEPLOY_SCRIPT
}

function Invoke-BuildOnlyDemo {
    Write-Header "仅构建演示"

    Write-Host "这个演示只执行构建流程：" -ForegroundColor Cyan
    Write-Host "1. 编译 .NET 项目" -ForegroundColor White
    Write-Host "2. 构建 Docker 镜像" -ForegroundColor White
    Write-Host "3. 跳过部署阶段" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "是否继续？(y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "演示已取消" -ForegroundColor Yellow
        return
    }

    Write-Info "执行仅构建流程..."
    & $BUILD_DEPLOY_SCRIPT -SkipDeploy -ImageTag "build-demo-$(Get-Date -Format 'HHmmss')"
}

function Invoke-DeployOnlyDemo {
    Write-Header "仅部署演示"

    Write-Host "这个演示只执行部署流程：" -ForegroundColor Cyan
    Write-Host "1. 跳过构建阶段" -ForegroundColor White
    Write-Host "2. 使用现有镜像部署" -ForegroundColor White
    Write-Host "3. 验证部署结果" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "是否继续？(y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "演示已取消" -ForegroundColor Yellow
        return
    }

    Write-Info "执行仅部署流程..."
    & $BUILD_DEPLOY_SCRIPT -SkipBuild -Force
}

function Invoke-PushDemo {
    Write-Header "推送镜像演示"

    Write-Host "这个演示将构建并推送镜像：" -ForegroundColor Cyan
    Write-Host "1. 编译 .NET 项目" -ForegroundColor White
    Write-Host "2. 构建 Docker 镜像" -ForegroundColor White
    Write-Host "3. 推送到 Docker 仓库" -ForegroundColor White
    Write-Host "4. 跳过本地部署" -ForegroundColor White
    Write-Host ""

    Write-Warn "注意：需要先设置 Docker 仓库凭据"
    Write-Host "运行: docker login" -ForegroundColor Gray
    Write-Host ""

    $username = Read-Host "输入 Docker Hub 用户名 (留空跳过推送演示)"
    if (-not $username) {
        Write-Host "推送演示已跳过" -ForegroundColor Yellow
        return
    }

    Write-Info "执行构建并推送流程..."
    & $BUILD_DEPLOY_SCRIPT -SkipDeploy -Push -Username $username -ImageTag "push-demo-$(Get-Date -Format 'yyyyMMdd-HHmm')"
}

function Invoke-DevBuildDemo {
    Write-Header "开发构建演示"

    Write-Host "这个演示展示开发环境的最佳实践：" -ForegroundColor Cyan
    Write-Host "1. 使用时间戳作为标签" -ForegroundColor White
    Write-Host "2. 完整构建和部署" -ForegroundColor White
    Write-Host "3. 适合开发迭代" -ForegroundColor White
    Write-Host ""

    $confirm = Read-Host "是否继续？(y/N)"
    if ($confirm -notmatch "^[Yy]$") {
        Write-Host "演示已取消" -ForegroundColor Yellow
        return
    }

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $tag = "dev-$timestamp"

    Write-Info "执行开发构建流程 (标签: $tag)..."
    & $BUILD_DEPLOY_SCRIPT -ImageTag $tag -Force
}

function Show-Menu {
    Write-Header "Nginx Manager Build & Deploy 演示"

    Write-Host "选择要运行的演示：" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1) 🔨 完整演示 - 编译+构建+部署" -ForegroundColor Yellow
    Write-Host "2) 🏗️ 仅构建演示 - 只构建镜像" -ForegroundColor Yellow
    Write-Host "3) 🚀 仅部署演示 - 只部署服务" -ForegroundColor Yellow
    Write-Host "4) 📤 推送演示 - 构建并推送镜像" -ForegroundColor Yellow
    Write-Host "5) 💻 开发构建演示 - 开发环境最佳实践" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "0) ❌ 退出演示" -ForegroundColor Yellow
    Write-Host ""

    $choice = Read-Host "请选择 (0-5)"

    switch ($choice) {
        "1" { Invoke-FullDemo }
        "2" { Invoke-BuildOnlyDemo }
        "3" { Invoke-DeployOnlyDemo }
        "4" { Invoke-PushDemo }
        "5" { Invoke-DevBuildDemo }
        "0" { Write-Host "再见！" -ForegroundColor Green; exit 0 }
        default { Write-Warn "无效选择，请重新选择" }
    }

    Write-Host ""
    Read-Host "按 Enter 键返回菜单..."
}

# ==========================
# 主函数
# ==========================

function Invoke-Main {
    # 检查脚本是否存在
    if (-not (Test-Path $BUILD_DEPLOY_SCRIPT)) {
        Write-Error "build-deploy.ps1 脚本未找到: $BUILD_DEPLOY_SCRIPT"
        exit 1
    }

    # 如果指定了演示类型，直接执行
    if ($Demo -ne "full") {
        switch ($Demo) {
            "build-only" { Invoke-BuildOnlyDemo }
            "deploy-only" { Invoke-DeployOnlyDemo }
            "push-demo" { Invoke-PushDemo }
            "dev-build" { Invoke-DevBuildDemo }
            default { Write-Error "无效的演示类型: $Demo" }
        }
        return
    }

    # 交互式菜单
    while ($true) {
        Show-Menu
    }
}

# ==========================
# 执行
# ==========================

Write-Host "Nginx Manager Build & Deploy 演示脚本" -ForegroundColor Cyan
Write-Host ""
Write-Host "这个脚本演示了 build-deploy.ps1 的各种用法" -ForegroundColor White
Write-Host ""

Invoke-Main
