/**
 * Minimal smoke test (no external test framework required).
 * Jenkins "Test" stage runs this with: npm test
 * Exits with non-zero code on failure so the pipeline stage fails correctly.
 */
const http = require('http');
const { spawn } = require('child_process');

const PORT = 4001;
const server = spawn('node', ['server.js'], {
  cwd: __dirname + '/..',
  env: { ...process.env, PORT },
});

function get(path) {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:${PORT}${path}`, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    }).on('error', reject);
  });
}

function fail(msg) {
  console.error(`FAIL: ${msg}`);
  server.kill();
  process.exit(1);
}

setTimeout(async () => {
  try {
    const health = await get('/health');
    if (health.status !== 200) fail(`/health returned ${health.status}`);
    if (!health.body.includes('ok')) fail('/health did not return ok status');

    const info = await get('/api/info');
    if (info.status !== 200) fail(`/api/info returned ${info.status}`);

    const metrics = await get('/metrics');
    if (metrics.status !== 200) fail(`/metrics returned ${metrics.status}`);

    console.log('PASS: all smoke tests passed');
    server.kill();
    process.exit(0);
  } catch (err) {
    fail(err.message);
  }
}, 1000);
