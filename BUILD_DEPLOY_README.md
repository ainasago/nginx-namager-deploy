# Nginx Manager Build & Deploy Script

## 📋 概述

`build-deploy.ps1` 是一个一体化脚本，用于编译 Nginx Manager 的 .NET 源码、构建 Docker 镜像，并自动部署服务。这个脚本结合了构建和部署功能，适合开发和快速部署场景。

## 🚀 快速开始

### 基本使用（编译+构建+部署）

```powershell
# 在 scripts 目录下执行
.\build-deploy.ps1
```

这个命令会：
1. 编译 .NET 项目
2. 构建 Docker 镜像
3. 部署服务到本地
4. 验证部署结果

### 构建并推送镜像

```powershell
# 构建并推送到 Docker Hub
.\build-deploy.ps1 -Push -Username yourusername -ImageTag v1.0.0
```

### 仅构建（不部署）

```powershell
# 只构建镜像，不部署
.\build-deploy.ps1 -SkipDeploy -ImageTag dev-build
```

### 仅部署（使用现有镜像）

```powershell
# 跳过构建，直接部署
.\build-deploy.ps1 -SkipBuild -Force
```

## ⚙️ 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `-ImageTag` | string | `latest` | Docker 镜像标签 |
| `-Registry` | string | `docker.io` | Docker 仓库地址 |
| `-Username` | string | - | 仓库用户名（推送时必需） |
| `-ImageName` | string | `nginx-manager` | 镜像名称 |
| `-Push` | switch | false | 构建后推送镜像到仓库 |
| `-NoCache` | switch | false | 构建时不使用缓存 |
| `-Force` | switch | false | 强制重新构建和部署 |
| `-SkipBuild` | switch | false | 跳过构建阶段，仅部署 |
| `-SkipDeploy` | switch | false | 跳过部署阶段，仅构建 |
| `-Silent` | switch | false | 静默模式，最小化输出 |
| `-Help` | switch | false | 显示帮助信息 |

## 📝 使用场景

### 开发环境

```powershell
# 快速开发构建和部署
.\build-deploy.ps1 -ImageTag "dev-$(Get-Date -Format 'yyyyMMdd-HHmm')"

# 仅构建用于测试
.\build-deploy.ps1 -SkipDeploy -ImageTag test-build
```

### 生产环境

```powershell
# 构建生产版本并推送
.\build-deploy.ps1 -ImageTag v1.0.0 -Push -Username mycompany

# 部署已有的生产镜像
.\build-deploy.ps1 -SkipBuild -Force
```

### CI/CD 场景

```powershell
# 在构建流水线中使用
.\build-deploy.ps1 -ImageTag "$env:BUILD_NUMBER" -Push -Username "$env:DOCKER_USERNAME" -Silent
```

## 🔄 工作流程

### 完整流程（默认）

```
环境检查 → 编译源码 → 构建镜像 → 推送镜像 → 部署服务 → 验证部署
```

### 仅构建流程

```
环境检查 → 编译源码 → 构建镜像 → 推送镜像
```

### 仅部署流程

```
部署服务 → 验证部署
```

## 🛠️ 功能特性

### 智能构建
- ✅ 自动检测 .NET SDK 和 Docker 环境
- ✅ 使用现有的 `build-image.ps1` 脚本进行构建
- ✅ 支持多平台 Dockerfile 自动选择

### 灵活部署
- ✅ 调用现有的 `deploy.ps1` 脚本进行部署
- ✅ 自动处理容器冲突（使用 `-Force` 参数）
- ✅ 支持静默部署模式

### 完整验证
- ✅ 部署后自动验证服务状态
- ✅ 健康检查确保服务正常运行
- ✅ 详细的状态报告

## 📊 与其他脚本的关系

| 脚本 | 功能 | 适用场景 |
|------|------|----------|
| `build-deploy.ps1` | 编译+构建+部署一体化 | 开发和快速部署 |
| `build-image.ps1` | 仅编译和构建镜像 | 需要自定义构建流程 |
| `deploy.ps1` | 仅部署现有镜像 | 生产环境部署 |
| `update.ps1` | 更新现有部署 | 版本升级 |

## 🔧 故障排除

### 构建失败

```powershell
# 检查 .NET SDK
dotnet --version

# 检查项目结构
Test-Path ..\NginxManager\NginxManager.csproj

# 强制重新构建
.\build-deploy.ps1 -Force -NoCache
```

### 部署失败

```powershell
# 检查 Docker 状态
docker info

# 检查端口占用
netstat -ano | findstr :7000

# 强制重新部署
.\build-deploy.ps1 -SkipBuild -Force
```

### 推送失败

```powershell
# 检查登录状态
docker login

# 检查仓库权限
docker push <your-image>:test
```

## 📋 输出示例

### 成功执行

```
============================================
Nginx Manager Build & Deploy
============================================
ℹ Checking environment...
✓ .NET SDK: 9.0.100
✓ Docker: Docker version 24.0.6
✓ Docker daemon is running
✓ Project files found

============================================
🔨 Build Phase
============================================
ℹ Building image: nginx-manager:v1.0.0
✓ Build phase completed successfully

============================================
🚀 Deploy Phase
============================================
ℹ Deploying with built image
✓ Deploy phase completed successfully

============================================
🔍 Verification Phase
============================================
ℹ Verifying deployment...
✓ Container is running
✓ Health check passed - service is responding

============================================
🎉 Build & Deploy Complete!
============================================
Nginx Manager has been successfully built and deployed!

🌐 Access URLs:
   Web Interface: http://localhost:7000
   HTTPS Interface: https://localhost:8443
```

## 💡 使用建议

1. **开发阶段**: 使用 `.\build-deploy.ps1` 快速迭代
2. **测试部署**: 使用 `.\build-deploy.ps1 -SkipBuild` 测试部署逻辑
3. **生产发布**: 使用 `.\build-deploy.ps1 -Push` 构建和发布
4. **CI/CD**: 使用 `-Silent` 参数减少输出
5. **故障排除**: 使用 `-Force` 参数强制重新执行

## 📞 技术支持

如果遇到问题：

1. 查看详细错误信息（移除 `-Silent` 参数）
2. 检查各个阶段的日志输出
3. 验证环境依赖（.NET SDK、Docker）
4. 尝试分阶段执行（`-SkipBuild` 或 `-SkipDeploy`）

## 🔄 版本历史

- **v1.0.0**: 初始版本，支持完整的构建部署流程
- 集成现有的构建和部署脚本
- 支持灵活的参数配置
- 完整的错误处理和验证机制
