const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');
const D = __dirname;
const FPS = 30;
const only = process.argv[2] ? process.argv[2].split(',').map(Number) : null; // preview times (seconds)

const srv = http.createServer((q, r) => {
  const f = path.join(D, q.url === '/' ? 'index.html' : path.normalize(q.url.split('?')[0]).replace(/^(\.\.[\/\\])+/, ''));
  fs.readFile(f, (e, b) => {
    if (e) { r.writeHead(404); r.end(); return; }
    r.writeHead(200, { 'Content-Type': f.endsWith('.json') ? 'application/json' : 'text/html' });
    r.end(b);
  });
});

(async () => {
  await new Promise(r => srv.listen(0, r));
  const port = srv.address().port;
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1920, height: 1080 } });
  await p.goto(`http://localhost:${port}/`);
  await p.evaluate(() => window.ready);
  await p.evaluate(() => document.fonts.ready);
  const total = await p.evaluate(() => window.TOTAL());
  const tl = await p.evaluate(() => window.timeline());
  fs.mkdirSync(path.join(D, 'build'), { recursive: true });
  fs.writeFileSync(path.join(D, 'build', 'timeline.json'), JSON.stringify(tl));
  const out = path.join(D, 'build', only ? 'preview' : 'png');
  fs.mkdirSync(out, { recursive: true });
  if (only) {
    for (const t of only) {
      await p.evaluate(t => window.render(t), t);
      await p.screenshot({ path: path.join(out, `p${String(t).replace('.', '_')}.png`) });
    }
  } else {
    const n = Math.round(total * FPS);
    for (let i = 0; i < n; i++) {
      await p.evaluate(t => window.render(t), i / FPS);
      await p.screenshot({ path: path.join(out, `f${String(i).padStart(5, '0')}.png`) });
    }
    console.log('frames', n, 'seconds', total);
  }
  await b.close(); srv.close();
})();
