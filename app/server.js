/**
 * DevOps Capstone Project - Node.js Web Application
 * Simple Express app with health check and Prometheus metrics
 * for use in an end-to-end CI/CD pipeline demo.
 */

const express = require('express');
const path = require('path');
const client = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;
const APP_VERSION = process.env.APP_VERSION || '1.0.0';

// ---- Prometheus metrics setup ----
const register = new client.Registry();
client.collectDefaultMetrics({ register });

const httpRequestCounter = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});
register.registerMetric(httpRequestCounter);

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
});
register.registerMetric(httpRequestDuration);

app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    const labels = { method: req.method, route: req.path, status_code: res.statusCode };
    httpRequestCounter.inc(labels);
    end(labels);
  });
  next();
});

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// ---- Routes ----
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.get('/api/info', (req, res) => {
  res.json({
    app: 'devops-capstone-app',
    version: APP_VERSION,
    hostname: require('os').hostname(),
    uptimeSeconds: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

// Health check endpoint - used by Docker HEALTHCHECK and load balancers
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Readiness endpoint - useful for orchestrators
app.get('/ready', (req, res) => {
  res.status(200).json({ status: 'ready' });
});

// Prometheus scrape endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

app.listen(PORT, () => {
  console.log(`devops-capstone-app v${APP_VERSION} listening on port ${PORT}`);
});

module.exports = app;
