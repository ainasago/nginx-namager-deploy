# Nginx Manager - Docker 部署包

Nginx Manager 是一个基于 .NET Core 的 Nginx 服务器管理工具，支持可视化配置和管理 Nginx 服务器。

## 🚀 快速开始

### Windows 用户

1. 确保已安装 Docker Desktop
2. 下载所有文件到同一目录
3. 运行 PowerShell 脚本：

```powershell
.\deploy.ps1
```

### Linux 用户

1. 确保已安装 Docker 和 Docker Compose
2. 下载所有文件到同一目录
3. 给脚本执行权限并运行：

```bash
chmod +x deploy.sh
./deploy.sh
```

### 手动部署

如果脚本无法运行，可以手动执行：

```bash
# 1. 拉取镜像
docker pull docker.io/wtation/nginx-manager:latest

# 2. 启动服务
docker-compose --env-file config.env up -d
```

## 📋 文件说明

- `docker-compose.yml` - Docker 服务配置
- `config.env` - 环境配置文件（可修改端口等设置）
- `deploy.ps1` - Windows 自动部署脚本
- `deploy.sh` - Linux 自动部署脚本

## 🔧 配置说明

编辑 `config.env` 文件可以修改以下设置：

- `EXTERNAL_HTTP_PORT` - 外部访问的 HTTP 端口
- `EXTERNAL_HTTPS_PORT` - 外部访问的 HTTPS 端口
- `DATA_BASE_DIR` - 数据存储目录

## 🌐 访问应用

部署成功后，通过以下地址访问：

- Web 界面：`http://localhost:7000`
- HTTPS 界面：`https://localhost:8443`

## 📊 管理命令

```bash
# 查看服务状态
docker-compose --env-file config.env ps

# 查看日志
docker-compose --env-file config.env logs -f

# 停止服务
docker-compose --env-file config.env down

# 重启服务
docker-compose --env-file config.env restart
```

## 📁 数据目录

所有数据保存在 `./dockernpm-data/` 目录中：

- `data/` - 应用程序数据和数据库
- `nginx-instances/` - Nginx 实例配置
- `ssl/` - SSL 证书
- `logs/` - 日志文件
- `www/` - Web 根目录

## 🐛 故障排除

1. **端口占用**：修改 `config.env` 中的端口设置
2. **权限问题**：确保 Docker 有足够权限
3. **网络问题**：检查网络连接是否正常

## 📞 支持

如果遇到问题，请检查：

1. Docker 是否正常运行
2. 防火墙是否阻止相关端口
3. 系统是否有足够的资源

---

**当前版本**: 使用镜像 `docker.io/wtation/nginx-manager:latest`
