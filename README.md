# Tautomation — 让天下没有难用的特斯拉

特斯拉车主的自动化助手。规则可视化构建，触发即推送，开箱即用的预设。

> 内部代号 / 包名仍是 `TePlanner` / `com.teplanner.ios` —— 改名保持
> bundle id / domain / Swift 包名稳定（参考 Meta 留 `com.facebook.*` 的做法）。
> 用户看到的是 Tautomation。

## 核心能力

- **可视化自动化构建器**：trigger / action 块状画布，5 类车辆状态可观察
- **预设开箱即用**：露营超时 / 哨兵长开 / 座舱过热 / 充电完成 4 条预设，可直接启用或在此基础上微调
- **APNs 远程推送**：服务器持续轮询车辆状态，关 App 也能收到提醒
- **Tesla VCP 真车命令**：自动化触发后可直接「关闭露营」「关闭哨兵」「调充电限额」等
- **充电路线规划**：保留功能，作为 Hub 子页（不是头部主推）

## 技术栈

### 后端

- Python 3.10+
- FastAPI
- SQLAlchemy (异步)
- Redis (缓存)

### 前端

- 微信小程序原生开发
- 腾讯地图组件

### 部署

- Serverless (AWS Lambda / 腾讯云函数)
- Docker (本地开发)

## 项目结构

```
TePlanner/
├── backend/          # 后端服务 (FastAPI)
│   ├── app/
│   │   ├── api/      # API路由
│   │   ├── core/     # 核心模块
│   │   ├── models/   # 数据模型
│   │   ├── schemas/  # Pydantic Schema
│   │   ├── services/ # 业务逻辑
│   │   └── integrations/  # 第三方API集成
│   │       ├── tesla/     # Tesla API (MVP核心)
│   │       └── tencent_map/  # 腾讯地图
│   └── tests/
├── docs/             # 项目文档
├── PRD.md            # 产品需求文档
└── README.md         # 本文件
```

## 快速开始

### 环境要求

- Python 3.10+
- Node.js 16+ (Serverless Framework)
- 微信开发者工具

### 后端开发

```bash
# 进入后端目录
cd backend

# 创建虚拟环境
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements-dev.txt

# 配置环境变量
cp ../.env.example .env
# 编辑 .env 填入实际配置

# 运行开发服务器
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 小程序开发

1. 使用微信开发者工具打开 `miniprogram` 目录
2. 配置 AppID
3. 修改 `config/api.js` 中的后端地址

## Tesla API 集成

MVP 阶段使用 Tesla Owner API（非官方）获取车辆数据，同时申请官方 Fleet API。

详细说明请参考 [docs/tesla-api-integration.md](docs/tesla-api-integration.md)

## API 文档

启动后端后访问：

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 开发路线

- [x] 项目初始化
- [ ] Tesla API 对接验证
- [ ] 基础路线规划
- [ ] 能耗模型实现
- [ ] 小程序 MVP
- [ ] Fleet API 切换

## 贡献指南

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 许可证

MIT License

## 联系方式

- 项目仓库：https://gitee.com/jack91620/te-planner
