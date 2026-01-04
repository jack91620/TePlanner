# TePlanner 部署指南

## 前置要求

- Python 3.11+
- PostgreSQL 14+
- Docker（可选，用于容器化部署）
- 腾讯云账号（生产环境）
- 微信小程序开发者账号

## 本地开发环境

### 1. 后端配置

```bash
# 克隆仓库
cd TePlanner/backend

# 创建 conda 环境
conda create -n teplanner python=3.11 -y
conda activate teplanner

# 安装依赖
pip install -r requirements.txt
pip install -r requirements-dev.txt

# 复制环境变量模板
cp ../.env.example .env
# 编辑 .env 填入配置

# 运行数据库迁移
alembic upgrade head

# 启动开发服务器
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. 环境变量配置

创建 `.env` 文件:

```env
# 应用配置
DEBUG=true
SECRET_KEY=your-secret-key-here

# 数据库
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/teplanner

# Tesla API
TESLA_API_BASE_URL=https://owner-api.teslamotors.com
TESLA_CLIENT_ID=your-client-id
TESLA_TOKEN_ENCRYPTION_KEY=your-fernet-key

# 腾讯地图
TENCENT_MAP_API_KEY=your-tencent-map-key

# 微信
WECHAT_APP_ID=your-wechat-appid
WECHAT_APP_SECRET=your-wechat-secret
```

### 3. 小程序配置

```bash
# 打开微信开发者工具
# 导入项目: TePlanner/miniprogram

# 更新 config/index.js 中的 API 地址
# 更新 project.config.json 中的 AppID
```

## Docker 部署

### 构建镜像

```bash
cd TePlanner/backend
docker build -t teplanner-backend:latest .
```

### 运行容器

```bash
docker run -d \
  --name teplanner-api \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://... \
  -e TESLA_CLIENT_ID=... \
  teplanner-backend:latest
```

### Docker Compose (开发环境)

```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build: ./backend
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql+asyncpg://postgres:postgres@db:5432/teplanner
    depends_on:
      - db

  db:
    image: postgres:14
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=teplanner
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

## 生产环境部署 (腾讯云)

### 1. 云函数 (SCF)

```bash
# 安装 Serverless Framework
npm install -g serverless

# 部署
cd TePlanner/backend
serverless deploy
```

### 2. 数据库 (TencentDB)

1. 在腾讯云控制台创建 PostgreSQL 实例
2. 配置 VPC 和安全组
3. 更新云函数中的 DATABASE_URL

### 3. CDN 配置

1. 创建 COS 存储桶用于静态资源
2. 配置 CDN 指向 COS
3. 启用 HTTPS 证书

### 4. 域名配置

1. 注册域名（如未拥有）
2. 配置 DNS 指向 SCF/CDN
3. 启用 HTTPS 证书

## 小程序发布

### 1. 开发版本

- 使用微信开发者工具的预览功能
- 用微信扫描二维码预览

### 2. 正式发布

```text
在微信开发者工具中:
1. 点击"上传"按钮
2. 填写版本号和描述
3. 在小程序管理后台提交审核
4. 等待审核通过（通常1-3天）
5. 发布上线
```

## 监控运维

### 健康检查

```bash
curl https://api.teplanner.com/health
# 响应: {"status": "healthy", "version": "0.1.0"}
```

### 日志查看

- SCF: 在腾讯云控制台查看
- Docker: `docker logs teplanner-api`
- 本地: 查看终端输出

### 监控指标

- API 响应时间
- 错误率
- Tesla API 调用成功率
- 活跃用户数

## 故障排查

### 常见问题

1. **数据库连接失败**
   - 检查 DATABASE_URL 格式
   - 验证网络连通性
   - 检查用户名密码

2. **Tesla API 401 错误**
   - Token 可能已过期，需要刷新
   - 检查 TESLA_CLIENT_ID 配置

3. **小程序网络请求失败**
   - 确认 API 域名在小程序白名单中
   - 检查 HTTPS 证书有效性

### 获取支持

如有问题，请在 GitHub 创建 Issue，并提供:
- 错误信息
- 复现步骤
- 环境信息
