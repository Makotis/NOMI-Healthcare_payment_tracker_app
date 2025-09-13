# Healthcare Payment Tracker - Docker Deployment

A containerized healthcare payment tracking application built with HTML, CSS, JavaScript, and deployed using Docker Compose with Nginx.

## 🚀 Quick Start

### Prerequisites
- Docker installed on your system
- Docker Compose installed on your system

### Deploy the Application

1. **Clone or navigate to the project directory:**
   ```bash
   cd HEALTHCARE-PAYMENT-APP
   ```

2. **Build and start the container:**
   ```bash
   docker-compose up -d --build
   ```

3. **Access the application:**
   Open your web browser and navigate to:
   ```
   http://localhost:8080
   ```

### Docker Commands

- **Start the application:**
  ```bash
  docker-compose up -d
  ```

- **Stop the application:**
  ```bash
  docker-compose down
  ```

- **View logs:**
  ```bash
  docker-compose logs -f healthcare-app
  ```

- **Rebuild and restart:**
  ```bash
  docker-compose up -d --build --force-recreate
  ```

- **Check container status:**
  ```bash
  docker-compose ps
  ```

## 🏗️ Architecture

### Container Stack
- **Base Image:** `nginx:alpine` (lightweight and secure)
- **Web Server:** Nginx with custom configuration
- **Network:** Isolated Docker bridge network
- **Port Mapping:** Host port 8080 → Container port 80

### File Structure
```
HEALTHCARE-PAYMENT-APP/
├── index.html          # Main application HTML
├── app.js              # JavaScript application logic
├── styles.css          # Application styles
├── Dockerfile          # Container build instructions
├── docker-compose.yml  # Container orchestration
├── nginx.conf          # Nginx web server configuration
├── .dockerignore       # Files to exclude from build
└── README.md          # This file
```

## ⚙️ Configuration

### Nginx Features
- **Gzip Compression:** Enabled for better performance
- **Security Headers:** XSS protection, content type options
- **Static Asset Caching:** 1-year cache for CSS/JS files
- **Health Check Endpoint:** `/health` for monitoring
- **Single Page App Support:** Fallback routing to index.html

### Docker Compose Configuration
```yaml
services:
  healthcare-app:
    build: .
    ports:
      - "8080:80"
    restart: unless-stopped
    networks:
      - healthcare-network
```

## 🔧 Customization

### Change Port
Edit `docker-compose.yml` and modify the port mapping:
```yaml
ports:
  - "3000:80"  # Changes host port to 3000
```

### Environment Variables
Add environment-specific configurations in `docker-compose.yml`:
```yaml
environment:
  - NODE_ENV=production
  - API_URL=https://api.example.com
```

### Volume Persistence
To persist data, add volumes to `docker-compose.yml`:
```yaml
volumes:
  - healthcare-data:/usr/share/nginx/html/data
```

## 🔍 Monitoring

### Health Check
The application includes a health endpoint:
```bash
curl http://localhost:8080/health
```

### Container Metrics
View container resource usage:
```bash
docker stats healthcare-payment-tracker
```

## 🔒 Security

The Nginx configuration includes:
- Security headers (XSS protection, content type options)
- Server tokens disabled
- Content Security Policy
- Frame options protection

## 🐛 Troubleshooting

### Common Issues

1. **Port Already in Use:**
   ```bash
   # Find process using port 8080
   netstat -tulpn | grep :8080
   # Or change port in docker-compose.yml
   ```

2. **Container Won't Start:**
   ```bash
   # Check logs for errors
   docker-compose logs healthcare-app
   ```

3. **Application Not Loading:**
   ```bash
   # Verify container is running
   docker-compose ps
   # Check if files are copied correctly
   docker exec -it healthcare-payment-tracker ls -la /usr/share/nginx/html/
   ```

4. **Permission Issues:**
   ```bash
   # Rebuild with no cache
   docker-compose build --no-cache
   ```

### Logs Location
- **Nginx Access Logs:** `/var/log/nginx/access.log`
- **Nginx Error Logs:** `/var/log/nginx/error.log`
- **Container Logs:** `docker-compose logs`

## 📊 Features

- **Payment Tracking:** Manage healthcare payments and claims
- **Provider Management:** Track healthcare providers
- **Dashboard Analytics:** Visual overview of payment statistics
- **Data Export:** CSV export functionality
- **Responsive Design:** Mobile and desktop friendly
- **Offline Capable:** No external dependencies

## 🚀 Production Deployment

For production deployment, consider:

1. **Use HTTPS:** Add SSL certificates and configure Nginx for HTTPS
2. **Environment Variables:** Store sensitive configuration externally
3. **Health Checks:** Implement proper health monitoring
4. **Backup Strategy:** Regular backups of application data
5. **Resource Limits:** Set memory and CPU limits in docker-compose.yml

### Production Example
```yaml
services:
  healthcare-app:
    build: .
    restart: always
    deploy:
      resources:
        limits:
          memory: 256M
          cpus: '0.5'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## 📝 License

This project is for demonstration purposes. Ensure compliance with healthcare data regulations (HIPAA, etc.) before using in production environments.