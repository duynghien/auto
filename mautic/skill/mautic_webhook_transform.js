/**
 * mautic_webhook_transform.js
 * OpenClaw Webhook Transform Module for Mautic 7
 * 
 * This module catches incoming bloated JSON payloads from Mautic Webhooks,
 * extracts only the vital information (like email, name, event type),
 * and formats it into a concise message for the Pi Agent.
 */

function transform(req) {
    // If there's no body, just return a generic wake-up
    if (!req.body || typeof req.body !== "object") {
        return {
            message: "Received an empty webhook event from Mautic.",
            name: "Mautic",
            wakeMode: "now"
        };
    }

    // The Mautic payload often nests data. Let's look for standard structures.
    const body = req.body;

    // Try to find the leading event type. Usually Mautic has a primary key 
    // tied to the event context (e.g. 'contact', 'form', 'lead').
    let eventType = "Sự kiện Mautic";
    let contactName = "Khách hàng lạ";
    let contactEmail = "Không rõ email";
    let details = "";

    // 1. Check for Form Submit
    if (body.submission || body.form) {
        eventType = "Khách vừa điền Form";
        if (body.lead) {
            contactEmail = body.lead.email || contactEmail;
            contactName = `${body.lead.firstname || ""} ${body.lead.lastname || ""}`.trim() || contactName;
        }
        details = `Form ID: ${body.form ? body.form.id : "N/A"}`;
    }
    // 2. Check for Contact (Lead) generic events
    else if (body.lead || body.contact) {
        const lead = body.lead || body.contact;
        contactEmail = lead.email || (lead.fields && lead.fields.core && lead.fields.core.email && lead.fields.core.email.value) || contactEmail;

        let fn = lead.firstname || (lead.fields && lead.fields.core && lead.fields.core.firstname && lead.fields.core.firstname.value) || "";
        let ln = lead.lastname || (lead.fields && lead.fields.core && lead.fields.core.lastname && lead.fields.core.lastname.value) || "";
        contactName = `${fn} ${ln}`.trim() || contactName;

        // Point changes check
        if (body.points) {
            eventType = "Thay đổi điểm Lead Score";
            details = `Sự kiện: ${body.points.event_name || 'N/A'} - Khách hiện có ${lead.points || 'N/A'} điểm.`;
        }
        // Segment changes check
        else if (body.lists || body.segments) {
            eventType = "Khách thay đổi Segment";
        }
        // Identified check
        else if (req.url && req.url.includes('identified')) {
            eventType = "Đã định danh khách hàng mới";
        }
        // Updated check
        else {
            eventType = "Cập nhật hồ sơ khách hàng";
        }
    }

    // Construct a concise message for the Pi Agent
    const agentMessage = `🔔 [System: Mautic Alert] Báo động từ hệ thống Marketing Automation!
- Hành động: ${eventType}
- Tên khách hàng: ${contactName}
- Email liên hệ: ${contactEmail}
- Ghi chú thêm: ${details}

Bạn là trợ lý AI. Dựa trên thông tin này, hãy dùng kỹ năng (skills) 'get_contact' của Mautic để tra thêm thông tin và quyết định xem có cần chúc mừng, phân loại (tag), hay đẩy họ vào danh sách (segment) nào không.`;

    // Return the strict Agent format expected by OpenClaw's generic webhook ingestion
    return {
        message: agentMessage,
        name: "Mautic Webhook",
        wakeMode: "now" // Instantly wake the agent to process this
    };
}

module.exports = { transform };
