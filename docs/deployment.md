# TePlanner Deployment Guide

## Prerequisites

- Python 3.11+
- PostgreSQL 14+
- Docker (optional, for containerized deployment)
- Tencent Cloud account (for production)
- WeChat Mini Program developer account

## Local Development Setup

### 1. Backend Setup

```bash
# Clone repository
cd TePlanner/backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or: venv\Scripts\activate  # Windows

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Copy environment template
cp ../.env.example .env
# Edit .env with your configuration

# Run database migrations
alembic upgrade head

# Start development server
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 2. Environment Variables

Create `.env` file with:

```env
# App
DEBUG=true
SECRET_KEY=your-secret-key-here

# Database
DATABASE_URL=postgresql+asyncpg://user:pass@localhost:5432/teplanner

# Tesla API
TESLA_API_BASE_URL=https://owner-api.teslamotors.com
TESLA_CLIENT_ID=your-client-id
TESLA_TOKEN_ENCRYPTION_KEY=your-fernet-key

# Tencent Map
TENCENT_MAP_API_KEY=your-tencent-map-key

# WeChat
WECHAT_APP_ID=your-wechat-appid
WECHAT_APP_SECRET=your-wechat-secret
```

### 3. Mini Program Setup

```bash
# Open WeChat DevTools
# Import project: TePlanner/miniprogram

# Update config/index.js with your API URL
# Update project.config.json with your AppID
```

## Docker Deployment

### Build Image

```bash
cd TePlanner/backend
docker build -t teplanner-backend:latest .
```

### Run Container

```bash
docker run -d \
  --name teplanner-api \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://... \
  -e TESLA_CLIENT_ID=... \
  teplanner-backend:latest
```

### Docker Compose (Development)

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

## Production Deployment (Tencent Cloud)

### 1. Serverless Cloud Function (SCF)

```bash
# Install Serverless Framework
npm install -g serverless

# Deploy
cd TePlanner/backend
serverless deploy
```

### 2. Database (TencentDB)

1. Create PostgreSQL instance in Tencent Cloud console
2. Configure VPC and security groups
3. Update DATABASE_URL in SCF environment

### 3. CDN Configuration

1. Create COS bucket for static assets
2. Configure CDN pointing to COS
3. Enable HTTPS with certificate

### 4. Domain Setup

1. Register domain (if not owned)
2. Configure DNS to point to SCF/CDN
3. Enable HTTPS certificate

## Mini Program Deployment

### 1. Development Version

- Use WeChat DevTools preview feature
- Scan QR code with WeChat

### 2. Production Release

```bash
# In WeChat DevTools:
1. Click "Upload" button
2. Fill in version number and description
3. Submit for review in MP admin console
4. Wait for approval (usually 1-3 days)
5. Release to production
```

## Monitoring

### Health Check

```bash
curl https://api.teplanner.com/health
# Response: {"status": "healthy", "version": "0.1.0"}
```

### Logs

- SCF: View in Tencent Cloud console
- Docker: `docker logs teplanner-api`
- Local: Check terminal output

### Metrics

- API response times
- Error rates
- Tesla API call success rate
- Active users

## Troubleshooting

### Common Issues

1. **Database connection failed**
   - Check DATABASE_URL format
   - Verify network connectivity
   - Check credentials

2. **Tesla API 401 errors**
   - Token may be expired, refresh needed
   - Check TESLA_CLIENT_ID configuration

3. **Mini program network errors**
   - Verify API domain is in whitelist
   - Check HTTPS certificate validity

### Support

For issues, create a GitHub issue with:
- Error message
- Steps to reproduce
- Environment details
