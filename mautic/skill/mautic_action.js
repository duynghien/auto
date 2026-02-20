#!/usr/bin/env node

/**
 * mautic_action.js
 * An OpenClaw Workspace Skill to interact with Mautic 7 REST API.
 * 
 * Provides an LLM interface to 5 core marketing automation functions:
 * 1. create_contact: Upsert a new lead by email.
 * 2. get_contact: Find lead info by email.
 * 3. add_tags: Assign specific tags to a contact (requires contact ID).
 * 4. add_to_segment: Add a contact ID to a specific Mautic segment.
 * 5. add_points: Add or subtract points from a contact ID.
 */

const https = require('https');
const http = require('http');

// Load environment variables globally injected by OpenClaw
const MAUTIC_URL = process.env.MAUTIC_BASE_URL || "http://localhost:8080";
const MAUTIC_USER = process.env.MAUTIC_API_USER;
const MAUTIC_PASS = process.env.MAUTIC_API_PASS;

if (!MAUTIC_USER || !MAUTIC_PASS) {
    console.error("Missing MAUTIC_API_USER or MAUTIC_API_PASS environment variables.");
    process.exit(1);
}

// Generate Basic Auth token
const authStr = Buffer.from(`${MAUTIC_USER}:${MAUTIC_PASS}`).toString('base64');

// Helper to sanitize Mautic Base URL
const getBaseUrl = () => {
    let url = MAUTIC_URL.endsWith('/') ? MAUTIC_URL.slice(0, -1) : MAUTIC_URL;
    return `${url}/api`;
};

/**
 * Lightweight HTTP/HTTPS request helper without using node-fetch (avoids dependencies)
 */
function mauticRequest(method, endpoint, payload = null) {
    return new Promise((resolve, reject) => {
        const fullUrl = new URL(`${getBaseUrl()}${endpoint}`);
        const engine = fullUrl.protocol === 'https:' ? https : http;

        const options = {
            hostname: fullUrl.hostname,
            port: fullUrl.port,
            path: fullUrl.pathname + fullUrl.search,
            method: method.toUpperCase(),
            headers: {
                'Authorization': `Basic ${authStr}`,
                'Accept': 'application/json'
            }
        };

        let requestBody = null;
        if (payload) {
            requestBody = JSON.stringify(payload);
            options.headers['Content-Type'] = 'application/json';
            options.headers['Content-Length'] = Buffer.byteLength(requestBody);
        }

        const req = engine.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const json = data ? JSON.parse(data) : {};
                    // Anything outside 2xx is considered an error locally
                    if (res.statusCode >= 200 && res.statusCode < 300) {
                        resolve(json);
                    } else {
                        reject({ status: res.statusCode, error: json });
                    }
                } catch (e) {
                    reject({ status: res.statusCode, error: data });
                }
            });
        });

        req.on('error', (e) => reject(e));

        if (requestBody) {
            req.write(requestBody);
        }
        req.end();
    });
}

// Ensure the CLI arguments are valid
if (process.argv.length < 4) {
    console.error("Usage: mautic_action.js <action_type> '<json_payload>'");
    console.error("Example: mautic_action.js get_contact '{\"email\": \"test@example.com\"}'");
    process.exit(1);
}

const actionType = process.argv[2];
let customPayload;

try {
    customPayload = JSON.parse(process.argv[3]);
} catch (e) {
    console.error("Invalid JSON payload provided as the second argument.");
    process.exit(1);
}

// Execute logic based on the Action Type requested by the Agent
async function run() {
    try {
        switch (actionType) {
            case 'create_contact':
                // Creating or updating based on email matches
                if (!customPayload.email) {
                    throw new Error("Payload must contain 'email' for create_contact");
                }
                const createResult = await mauticRequest('POST', '/contacts/new', customPayload);
                console.log(JSON.stringify(createResult));
                break;

            case 'get_contact':
                // Finding exact match by email
                if (!customPayload.email) {
                    throw new Error("Payload must contain 'email' for get_contact");
                }
                const searchEmail = encodeURIComponent(`email:${customPayload.email}`);
                const getResult = await mauticRequest('GET', `/contacts?search=${searchEmail}`);
                console.log(JSON.stringify(getResult));
                break;

            case 'add_tags':
                if (!customPayload.id || !customPayload.tags || !Array.isArray(customPayload.tags)) {
                    throw new Error("Payload must contain 'id' (contact ID) and 'tags' (array of strings)");
                }
                const tagResult = await mauticRequest('PUT', `/contacts/${customPayload.id}/edit`, {
                    tags: customPayload.tags
                });
                console.log(JSON.stringify(tagResult));
                break;

            case 'add_to_segment':
                if (!customPayload.contact_id || !customPayload.segment_id) {
                    throw new Error("Payload must contain 'contact_id' and 'segment_id'");
                }
                const segResult = await mauticRequest('POST', `/segments/${customPayload.segment_id}/contact/${customPayload.contact_id}/add`);
                console.log(JSON.stringify(segResult));
                break;

            case 'add_points':
                if (!customPayload.contact_id || !customPayload.points) {
                    throw new Error("Payload must contain 'contact_id' and 'points' (number)");
                }
                // Determine operator (+ or -)
                const pts = parseInt(customPayload.points, 10);
                const action = pts > 0 ? "plus" : "minus";
                const pResult = await mauticRequest('POST', `/contacts/${customPayload.contact_id}/points/${action}/${Math.abs(pts)}`);
                console.log(JSON.stringify(pResult));
                break;

            default:
                throw new Error(`Unknown Mautic action requested: ${actionType}`);
        }
    } catch (error) {
        console.error(JSON.stringify({
            "success": false,
            "message": error.message || "Failed to communicate with Mautic API",
            "details": error.error || error
        }));
        // We still exit 0 so OpenClaw LLM can read the exact error output in JSON cleanly.
        process.exit(0);
    }
}

run();
