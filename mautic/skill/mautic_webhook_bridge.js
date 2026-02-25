#!/usr/bin/env node
/**
 * Mautic -> OpenClaw webhook bridge
 *
 * Why needed:
 * - Many Mautic installs expose only URL + Secret in Webhook UI (no custom headers).
 * - OpenClaw /hooks endpoints require Bearer token auth.
 *
 * This bridge:
 * 1) Receives Mautic webhook
 * 2) Verifies Webhook-Signature with MAUTIC_WEBHOOK_SECRET
 * 3) Forwards payload to OpenClaw hooks endpoint with Bearer token
 */

const http = require('http');
const crypto = require('crypto');

const LISTEN_HOST = process.env.MAUTIC_BRIDGE_HOST || '127.0.0.1';
const LISTEN_PORT = Number(process.env.MAUTIC_BRIDGE_PORT || 18889);
const LISTEN_PATH = process.env.MAUTIC_BRIDGE_PATH || '/mautic-webhook';

const MAUTIC_WEBHOOK_SECRET = process.env.MAUTIC_WEBHOOK_SECRET;
const OPENCLAW_HOOK_URL = process.env.OPENCLAW_HOOK_URL || 'http://127.0.0.1:18799/hooks/mautic';
const OPENCLAW_HOOK_TOKEN = process.env.OPENCLAW_HOOK_TOKEN;

if (!MAUTIC_WEBHOOK_SECRET) {
    console.error('Missing env: MAUTIC_WEBHOOK_SECRET');
    process.exit(1);
}
if (!OPENCLAW_HOOK_TOKEN) {
    console.error('Missing env: OPENCLAW_HOOK_TOKEN');
    process.exit(1);
}

function json(res, code, data) {
    const body = JSON.stringify(data);
    res.writeHead(code, { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) });
    res.end(body);
}

async function forwardToOpenClaw(rawBody) {
    const target = new URL(OPENCLAW_HOOK_URL);
    const isHttps = target.protocol === 'https:';
    const engine = isHttps ? require('https') : require('http');

    return new Promise((resolve, reject) => {
        const req = engine.request(
            {
                hostname: target.hostname,
                port: target.port || (isHttps ? 443 : 80),
                path: `${target.pathname}${target.search}`,
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${OPENCLAW_HOOK_TOKEN}`,
                    'Content-Length': Buffer.byteLength(rawBody),
                },
            },
            (res) => {
                let out = '';
                res.on('data', (c) => (out += c));
                res.on('end', () => {
                    resolve({ status: res.statusCode || 500, body: out });
                });
            }
        );

        req.on('error', reject);
        req.write(rawBody);
        req.end();
    });
}

const server = http.createServer(async (req, res) => {
    if (req.method !== 'POST' || req.url !== LISTEN_PATH) {
        return json(res, 404, { ok: false, error: 'not_found' });
    }

    let raw = '';
    req.on('data', (c) => (raw += c));
    req.on('end', async () => {
        try {
            const receivedSig = req.headers['webhook-signature'];
            if (!receivedSig || typeof receivedSig !== 'string') {
                return json(res, 401, { ok: false, error: 'missing_webhook_signature' });
            }

            const expected = crypto
                .createHmac('sha256', MAUTIC_WEBHOOK_SECRET)
                .update(raw)
                .digest('base64');

            if (receivedSig !== expected) {
                return json(res, 401, { ok: false, error: 'invalid_webhook_signature' });
            }

            const forwarded = await forwardToOpenClaw(raw);
            return json(res, 200, {
                ok: true,
                forwardedStatus: forwarded.status,
                forwardedBody: forwarded.body,
            });
        } catch (e) {
            return json(res, 500, { ok: false, error: String(e && e.message ? e.message : e) });
        }
    });
});

server.listen(LISTEN_PORT, LISTEN_HOST, () => {
    console.log(`Mautic bridge listening on http://${LISTEN_HOST}:${LISTEN_PORT}${LISTEN_PATH}`);
    console.log(`Forwarding to: ${OPENCLAW_HOOK_URL}`);
});
