import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import {
    CallToolRequestSchema,
    ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import axios from "axios";
import express from "express";
import cors from "cors";

// Configuration
const ANYCRAWL_API_URL = process.env.ANYCRAWL_API_URL || "http://localhost:8880";
const ANYCRAWL_API_KEY = process.env.ANYCRAWL_API_KEY || "YOUR_API_KEY";
const PORT = process.env.PORT || 8889;

// Helper function to call AnyCrawl API
async function callAnyCrawl(endpoint, method, data) {
    try {
        const url = `${ANYCRAWL_API_URL}${endpoint}`;
        console.error(`Calling AnyCrawl: ${method} ${url}`);
        const response = await axios({
            method,
            url,
            headers: {
                "Content-Type": "application/json",
                "x-api-key": ANYCRAWL_API_KEY // AnyCrawl use x-api-key
            },
            data,
        });
        return response.data;
    } catch (error) {
        console.error("AnyCrawl API Error:", error.message);
        if (error.response) {
            console.error("Response data:", error.response.data);
            throw new Error(`AnyCrawl API Error: ${JSON.stringify(error.response.data)}`);
        }
        throw error;
    }
}

// Helper to create a fresh server instance
// We need this because the SDK Server is stateful (once initialized, it rejects new initialize requests).
// For stateless HTTP (LobeHub), we treat each request as a fresh session.
const TOOLS = [
    {
        name: "crawl_url",
        description: "Crawl a single URL and return the content (markdown/html).",
        inputSchema: {
            type: "object",
            properties: {
                url: { type: "string", description: " The URL to crawl" },
            },
            required: ["url"],
        },
    },
    {
        name: "search",
        description: "Search the web using AnyCrawl's integrated search engine (SearXNG).",
        inputSchema: {
            type: "object",
            properties: {
                query: { type: "string", description: "Search query" },
                limit: { type: "number", description: "Number of results (default 5)" },
            },
            required: ["query"],
        },
    },
    {
        name: "crawl_status",
        description: "Check the status of a crawl job.",
        inputSchema: {
            type: "object",
            properties: {
                id: { type: "string", description: "Job ID returned by crawl_url" },
            },
            required: ["id"],
        },
    },
    {
        name: "scrape_url",
        description: "Scrape a single URL synchronously with optional AI extraction and screenshots.",
        inputSchema: {
            type: "object",
            properties: {
                url: { type: "string", description: "The URL to scrape" },
                engine: { type: "string", enum: ["playwright", "cheerio"], description: "Scraping engine to use" },
                json_options: {
                    type: "object",
                    description: "AI extraction schema. Example: { \"product_name\": \"string\", \"price\": \"number\" }"
                },
                screenshot: { type: "boolean", description: "Whether to capture a screenshot" }
            },
            required: ["url"],
        },
    },
    {
        name: "crawl_results",
        description: "Fetch the results of a completed crawl job.",
        inputSchema: {
            type: "object",
            properties: {
                id: { type: "string", description: "Job ID" },
                skip: { type: "number", description: "Number of results to skip (pagination)" }
            },
            required: ["id"],
        },
    },
    {
        name: "crawl_cancel",
        description: "Cancel an active crawl job.",
        inputSchema: {
            type: "object",
            properties: {
                id: { type: "string", description: "Job ID" }
            },
            required: ["id"],
        },
    },
    {
        name: "list_scheduled_tasks",
        description: "List all scheduled automation tasks.",
        inputSchema: { type: "object", properties: {} }
    },
    {
        name: "list_webhooks",
        description: "List all configured webhook subscriptions.",
        inputSchema: { type: "object", properties: {} }
    },
];

// Helper to create a fresh server instance for SSE
function createMCPServer() {
    const server = new Server(
        {
            name: "anycrawl-mcp",
            version: "1.0.0",
        },
        {
            capabilities: {
                tools: {},
            },
        }
    );

    server.setRequestHandler(ListToolsRequestSchema, async () => ({ tools: TOOLS }));

    server.setRequestHandler(CallToolRequestSchema, async (request) => {
        const { name, arguments: args } = request.params;
        try {
            let result;
            if (name === "crawl_url") {
                result = await callAnyCrawl("/v1/crawl", "POST", { url: args.url });
            } else if (name === "search") {
                result = await callAnyCrawl("/v1/search", "POST", { query: args.query, limit: args.limit || 5 });
            } else if (name === "crawl_status") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}/status`, "GET");
            } else if (name === "scrape_url") {
                result = await callAnyCrawl("/v1/scrape", "POST", {
                    url: args.url,
                    engine: args.engine || "playwright",
                    options: {
                        json_options: args.json_options,
                        formats: args.screenshot ? ["html", "markdown", "screenshot"] : ["html", "markdown"]
                    }
                });
            } else if (name === "crawl_results") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}?skip=${args.skip || 0}`, "GET");
            } else if (name === "crawl_cancel") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}`, "DELETE");
            } else if (name === "list_scheduled_tasks") {
                result = await callAnyCrawl("/v1/scheduled-tasks", "GET");
            } else if (name === "list_webhooks") {
                result = await callAnyCrawl("/v1/webhooks", "GET");
            } else {
                throw new Error(`Unknown tool: ${name}`);
            }

            return {
                content: [{ type: "text", text: JSON.stringify(result, null, 2) }],
            };
        } catch (error) {
            return {
                content: [{ type: "text", text: `Error: ${error.message}` }],
                isError: true,
            };
        }
    });

    return server;
}

// Global server for standard SSE connections (stateful)
const globalServer = createMCPServer();

const app = express();

// 1. Logger first to capture everything
app.use((req, res, next) => {
    // Log headers to debug what client sends
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url} - SessionID: ${req.query.sessionId || 'none'}`);
    console.log(`Buffers: headers=${JSON.stringify(req.headers)}`);
    next();
});

// 2. CORS with specific options
app.use(cors({
    origin: true, // Allow all origins reflected
    credentials: true,
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization", "x-api-key", "mcp-version", "x-session-id", "mcp-protocol-version"]
}));

app.use(express.json());

// Map to store active transports: sessionId -> transport
const transports = new Map();

app.get("/sse", async (req, res) => {
    console.log("New SSE connection attempt");

    // Create a new transport
    const transport = new SSEServerTransport("/sse", res);

    console.log(`Transport created, session ID: ${transport.sessionId}`);
    transports.set(transport.sessionId, transport);

    transport.onclose = () => {
        console.log(`Transport closed, session ID: ${transport.sessionId}`);
        transports.delete(transport.sessionId);
    };

    await globalServer.connect(transport);
});

// Manual MCP handler for stateless requests (LobeHub)
async function handleStatelessRequest(req, res) {
    const { jsonrpc, id, method, params } = req.body;
    console.log(`Handling stateless request: ${method} (ID: ${id})`);

    try {
        if (method === "initialize") {
            return res.json({
                jsonrpc: "2.0",
                id,
                result: {
                    protocolVersion: "2024-11-05",
                    capabilities: { tools: {} },
                    serverInfo: { name: "anycrawl-mcp", version: "1.0.0" }
                }
            });
        }

        if (method === "notifications/initialized") {
            return res.status(202).end();
        }

        if (method === "tools/list") {
            return res.json({
                jsonrpc: "2.0",
                id,
                result: { tools: TOOLS }
            });
        }

        if (method === "tools/call") {
            const { name, arguments: args } = params;
            console.log(`Tool call: ${name}`, args);

            let result;
            if (name === "crawl_url") {
                result = await callAnyCrawl("/v1/crawl", "POST", { url: args.url });
            } else if (name === "search") {
                result = await callAnyCrawl("/v1/search", "POST", { query: args.query, limit: args.limit || 5 });
            } else if (name === "crawl_status") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}/status`, "GET");
            } else if (name === "scrape_url") {
                result = await callAnyCrawl("/v1/scrape", "POST", {
                    url: args.url,
                    engine: args.engine || "playwright",
                    options: {
                        json_options: args.json_options,
                        formats: args.screenshot ? ["html", "markdown", "screenshot"] : ["html", "markdown"]
                    }
                });
            } else if (name === "crawl_results") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}?skip=${args.skip || 0}`, "GET");
            } else if (name === "crawl_cancel") {
                result = await callAnyCrawl(`/v1/crawl/${args.id}`, "DELETE");
            } else if (name === "list_scheduled_tasks") {
                result = await callAnyCrawl("/v1/scheduled-tasks", "GET");
            } else if (name === "list_webhooks") {
                result = await callAnyCrawl("/v1/webhooks", "GET");
            } else {
                return res.status(404).json({
                    jsonrpc: "2.0",
                    id,
                    error: { code: -32601, message: `Method not found: ${name}` }
                });
            }

            return res.json({
                jsonrpc: "2.0",
                id,
                result: {
                    content: [{ type: "text", text: JSON.stringify(result, null, 2) }]
                }
            });
        }

        // Generic error for unknown methods
        return res.status(404).json({
            jsonrpc: "2.0",
            id,
            error: { code: -32601, message: `Method not found: ${method}` }
        });

    } catch (error) {
        console.error("Stateless handler error:", error);
        return res.status(500).json({
            jsonrpc: "2.0",
            id,
            error: { code: -32603, message: error.message }
        });
    }
}

async function handleMessage(req, res) {
    const sessionId = req.query.sessionId;

    // 1. Try to find existing SSE transport
    if (sessionId) {
        const transport = transports.get(sessionId);
        if (transport) {
            await transport.handlePostMessage(req, res);
            return;
        }
    }

    // 2. Fallback: No session ID or no existing transport -> handle as stateless request
    console.log("No session ID or transport found, handling as stateless request.");
    await handleStatelessRequest(req, res);
}

// Handle POST on both endpoints
app.post("/sse", handleMessage);
app.post("/messages", handleMessage);

app.listen(PORT, () => {
    console.log(`AnyCrawl MCP Server running on port ${PORT}`);
    console.log(`SSE endpoint: http://localhost:${PORT}/sse`);
    console.log(`Message endpoint: http://localhost:${PORT}/sse`);
});
