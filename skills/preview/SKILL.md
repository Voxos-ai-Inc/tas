# /preview — Markdown Preview Server

Serve a `.md` file on localhost with rendered HTML preview.

## Usage

`/preview <path-to-md-file>`

If no file path is given, ask the user which `.md` file to preview.

## Behavior

1. Resolve the absolute path to the target `.md` file.
2. Create a minimal Node.js server script (in a temp location) that:
   - Reads the `.md` file from disk on each request (so edits are reflected on refresh).
   - Converts Markdown to HTML using a `<script>` tag loading **marked** from CDN.
   - Wraps the output in a clean HTML page with GitHub-style CSS from CDN.
   - Serves on `localhost:3333` (if taken, try 3334, 3335, etc.).
3. Start the server in the background.
4. Print the URL to the user: `Preview: http://localhost:<port>`

## Server Template

Use this inline HTML approach (no npm install needed):

```js
const http = require('http');
const fs = require('fs');
const path = require('path');

const FILE = process.argv[2];
const PORT = parseInt(process.argv[3] || '3333', 10);

const html = (md) => `<!DOCTYPE html>
<html><head>
<meta charset="utf-8">
<title>${path.basename(FILE)}</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/github-markdown-css/github-markdown.css">
<style>
  body { max-width: 800px; margin: 40px auto; padding: 0 20px; background: #fff; }
  .markdown-body { font-size: 16px; }
</style>
<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
</head><body>
<div class="markdown-body" id="content"></div>
<script>
document.getElementById('content').innerHTML = marked.parse(${JSON.stringify(md)});
</script>
</body></html>`;

const server = http.createServer((req, res) => {
  const md = fs.readFileSync(FILE, 'utf-8');
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(html(md));
});

server.listen(PORT, () => console.log('Preview: http://localhost:' + PORT));
```

## Key Rules

- No `npm install` — use only Node.js built-ins + CDN scripts.
- Re-read the file on every HTTP request so the user sees live changes on browser refresh.
- Run the server in the background so the conversation continues.
