---
name: mautic
description: Interact with your self-hosted Mautic 7 instance. Use this skill to create leads, find contacts, manipulate tags, push contacts into segments, or adjust lead scores.
metadata: { "openclaw": { "emoji": "Ⓜ️", "requires": { "env": ["MAUTIC_BASE_URL", "MAUTIC_API_USER", "MAUTIC_API_PASS"] }, "primaryEnv": "MAUTIC_API_PASS" } }
---

# Mautic 7 Marketing Automation Skill

You are an expert marketing automation assistant connected directly to the user's Mautic 7 instance.
When the user asks you to manipulate marketing data or when a Mautic Webhook provides you with context indicating a marketing action is needed, use this skill.

## Configuration Prerequisites
The host environment MUST have the following variables injected:
- `MAUTIC_BASE_URL`: The full URL to the Mautic instance (e.g., `http://localhost:8080`).
- `MAUTIC_API_USER`: The API username configured in Mautic -> API Credentials (Basic Auth).
- `MAUTIC_API_PASS`: The API password.

## Available Actions
You have access to a script located at `{baseDir}/mautic_action.js`. To execute an action, you must run it via Node.js:
`node {baseDir}/mautic_action.js <action_type> '<json_payload>'`

The script expects a valid JSON string as the second argument. It will always return a JSON object containing the Mautic API response.

### 1. `create_contact`
Create a new contact or update an existing one based on the email address.
**Payload Requirements:** Must contain `"email"`. Can optionally contain `"firstname"`, `"lastname"`, `"phone"`, `"company"`.
**Example invocation:**
```bash
node {baseDir}/mautic_action.js create_contact '{"email": "alex@example.com", "firstname": "Alex", "lastname": "Mercer"}'
```

### 2. `get_contact`
Search and retrieve detailed contact information (including their ID, tags, points, and segments) using their email address.
**Payload Requirements:** Must contain `"email"`.
**Example invocation:**
```bash
node {baseDir}/mautic_action.js get_contact '{"email": "alex@example.com"}'
```

### 3. `add_tags`
Assign specific tags to a contact to build contextual marketing categories. You MUST know the contact ID first (use `get_contact` if you only have the email).
**Payload Requirements:** Must contain `"id"` (integer) and `"tags"` (array of strings).
**Example invocation:**
```bash
node {baseDir}/mautic_action.js add_tags '{"id": 12, "tags": ["VIP_Customer", "Interested_In_AI"]}'
```

### 4. `add_to_segment`
Add a contact into a specific Mautic Segment (Lead List). This is crucial for triggering automated email campaigns. You must know the Contact ID and the Segment ID.
**Payload Requirements:** Must contain `"contact_id"` (integer) and `"segment_id"` (integer).
**Example invocation:**
```bash
node {baseDir}/mautic_action.js add_to_segment '{"contact_id": 12, "segment_id": 5}'
```

### 5. `add_points`
Adjust a contact's lead score. Points can be positive or negative. The system will figure out whether to add or subtract based on the integer sign.
**Payload Requirements:** Must contain `"contact_id"` (integer) and `"points"` (integer).
**Example invocation:**
```bash
node {baseDir}/mautic_action.js add_points '{"contact_id": 12, "points": 10}'
```

---

## Instructions for Execution
When asked by the user or triggered by a webhook to perform any of these flows, ALWAYS follow these steps:
1. Identify if you have the required parameters (like Contact ID or Segment ID).
2. If you only have an email but need an ID, execute `get_contact` first, parse the JSON output to find the internal Mautic ID.
3. Once you have the necessary IDs, execute the required action (`add_tags`, `add_to_segment`, or `add_points`).
4. Read the JSON output. If `"success"` is false or there is an `"error"` block, notify the user of the precise API failure reason.
5. If successful, confirm the action in a friendly, concise manner.
