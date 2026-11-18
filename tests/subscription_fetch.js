// Copyright (C) 2026 Cerostep

'use strict';

const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');

async function main() {
	const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'homeproxy-plus-fetch-'));
	fs.mkdirSync(path.join(dir, 'luci'));
	fs.writeFileSync(path.join(dir, 'luci/http.uc'),
		'export function urldecode_params(s) { return {}; }\n');

	const server = http.createServer((req, res) => {
		const url = new URL(req.url, 'http://127.0.0.1');
		if (url.pathname === '/redirect') {
			res.writeHead(302, { Location: '/subscription' }).end();
		} else if (url.pathname === '/failure') {
			res.writeHead(403).end('not a subscription');
		} else if (url.pathname === '/binary') {
			res.end(Buffer.from([0, 1, 2]));
		} else if (url.pathname === '/truncated') {
			res.writeHead(200, { 'Content-Length': 100 }).end('partial');
		} else if (url.pathname === '/slow') {
			res.writeHead(200).write('partial');
		} else if (url.pathname === '/empty') {
			res.end();
		} else {
			res.end(JSON.stringify({ agent: req.headers['user-agent'], query: url.searchParams.get('q') }));
		}
	});

	try {
		await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
		const base = `http://127.0.0.1:${server.address().port}`;
		const modulePath = path.join(__dirname, '../root/etc/homeproxy_plus/scripts/homeproxy_plus.uc');
		const code = `import { wGET } from '${modulePath}'; print(sprintf('%J', wGET(getenv('TEST_URL'), getenv('TEST_UA'))));`;

		function fetch(url, agent) {
			return new Promise((resolve, reject) => {
				const child = spawn('ucode', ['-L', dir, '-e', code], {
					env: { ...process.env, TEST_URL: url, TEST_UA: agent,
						NO_PROXY: '127.0.0.1', no_proxy: '127.0.0.1' }
				});
				let stdout = '', stderr = '';
				child.stdout.on('data', (data) => { stdout += data; });
				child.stderr.on('data', (data) => { stderr += data; });
				child.on('error', reject);
				child.on('close', (status) => {
					if (status !== 0)
						return reject(new Error(`ucode exited ${status}: ${stderr}`));
					resolve(JSON.parse(stdout));
				});
			});
		}

		const agent = "v2rayN 'test'";
		const payload = JSON.parse(await fetch(`${base}/subscription?q=one%27two`, agent));
		assert.equal(payload.agent, agent);
		assert.equal(payload.query, "one'two");
		const redirected = JSON.parse(await fetch(`${base}/redirect`, ''));
		assert.equal(redirected.agent, 'Wget/1.21 (HomeProxy-Plus, like v2rayN)');
		assert.equal(await fetch(`${base}/failure`, agent), null);
		assert.equal(await fetch(`${base}/binary`, agent), null);
		assert.equal(await fetch(`${base}/truncated`, agent), null);
		assert.equal(await fetch(`${base}/empty`, agent), '');
		const start = Date.now();
		assert.equal(await fetch(`${base}/slow`, agent), null);
		assert.ok(Date.now() - start >= 9000);
		console.log('Subscription curl fetch checks passed.');
	} finally {
		await new Promise((resolve) => server.close(resolve));
		fs.rmSync(dir, { recursive: true, force: true });
	}
}

main().catch((err) => {
	console.error(err);
	process.exitCode = 1;
});
