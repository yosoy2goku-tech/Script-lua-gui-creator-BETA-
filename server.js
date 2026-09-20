const express = require("express");
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const app = express();

const PORT = process.env.PORT || 3000;

// ===============================
// CONFIGURACIÓN
// ===============================

const SCRIPT_PATH = path.join(__dirname, "script.lua");

const TOKEN_LIFETIME = 30 * 1000; // 30 segundos
const MAX_REQUESTS_PER_MINUTE = 10;
const MAX_ACTIVE_TOKENS_PER_IP = 3;

// ===============================
// CARGAR SCRIPT
// ===============================

let SCRIPT;

try {
    SCRIPT = fs.readFileSync(SCRIPT_PATH, "utf8");
} catch (err) {
    console.error("ERROR: no se encontró script.lua");
    process.exit(1);
}

// ===============================
// MEMORIA DE SEGURIDAD
// ===============================

const requestLog = new Map();
const tokens = new Map();
const blockedIPs = new Map();

// ===============================
// UTILIDADES
// ===============================

function getIP(req) {
    return (
        req.headers["cf-connecting-ip"] ||
        req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
        req.socket.remoteAddress ||
        "unknown"
    );
}

function now() {
    return Date.now();
}

function cleanup() {
    const current = now();

    // Eliminar tokens expirados
    for (const [token, data] of tokens) {
        if (data.expires <= current) {
            tokens.delete(token);
        }
    }

    // Limpiar registros antiguos
    for (const [ip, data] of requestLog) {
        data.requests = data.requests.filter(
            time => current - time < 60000
        );

        if (data.requests.length === 0) {
            requestLog.delete(ip);
        }
    }

    // Quitar bloqueos expirados
    for (const [ip, expires] of blockedIPs) {
        if (expires <= current) {
            blockedIPs.delete(ip);
        }
    }
}

setInterval(cleanup, 10000);

// ===============================
// RATE LIMIT
// ===============================

function rateLimit(ip) {
    const current = now();

    if (!requestLog.has(ip)) {
        requestLog.set(ip, {
            requests: []
        });
    }

    const data = requestLog.get(ip);

    data.requests = data.requests.filter(
        time => current - time < 60000
    );

    data.requests.push(current);

    return data.requests.length <= MAX_REQUESTS_PER_MINUTE;
}

// ===============================
// BLOQUEO
// ===============================

function isBlocked(ip) {
    const expires = blockedIPs.get(ip);

    if (!expires) {
        return false;
    }

    if (expires <= now()) {
        blockedIPs.delete(ip);
        return false;
    }

    return true;
}

function blockIP(ip, seconds = 120) {
    blockedIPs.set(
        ip,
        now() + seconds * 1000
    );
}

// ===============================
// TOKEN TEMPORAL
// ===============================

function createToken(ip) {
    let active = 0;

    for (const [, data] of tokens) {
        if (data.ip === ip && data.expires > now()) {
            active++;
        }
    }

    if (active >= MAX_ACTIVE_TOKENS_PER_IP) {
        return null;
    }

    const token = crypto.randomBytes(32).toString("hex");

    tokens.set(token, {
        ip,
        created: now(),
        expires: now() + TOKEN_LIFETIME,
        used: false
    });

    return token;
}

// ===============================
// PÁGINA PRINCIPAL
// ===============================

app.get("/", (req, res) => {
    res.status(403)
        .type("text/plain")
        .send("Acceso denegado");
});

// ===============================
// LOADER PÚBLICO
// ===============================

app.get("/loader", (req, res) => {
    const ip = getIP(req);

    if (isBlocked(ip)) {
        return res
            .status(403)
            .type("text/plain")
            .send("Acceso denegado");
    }

    if (!rateLimit(ip)) {
        blockIP(ip, 120);

        return res
            .status(429)
            .type("text/plain")
            .send("Acceso temporalmente bloqueado");
    }

    const token = createToken(ip);

    if (!token) {
        blockIP(ip, 60);

        return res
            .status(429)
            .type("text/plain")
            .send("Demasiadas solicitudes");
    }

    /*
        El usuario solamente recibe este pequeño bootstrap.
        El script real se obtiene mediante /payload.
    */

    const bootstrap = `
local TOKEN = "${token}"

local URL = "https://script-lua-gui-creator-beta.onrender.com/payload"

local ok, result = pcall(function()
    return game:HttpGet(URL .. "?token=" .. TOKEN)
end)

if not ok then
    return
end

if type(result) ~= "string" then
    return
end

if result == "Acceso denegado" then
    return
end

local fn, err = loadstring(result)

if not fn then
    return
end

return fn()
`;

    res.setHeader(
        "Content-Type",
        "text/plain; charset=utf-8"
    );

    res.setHeader(
        "Cache-Control",
        "no-store, no-cache, must-revalidate"
    );

    res.status(200).send(bootstrap);
});

// ===============================
// SCRIPT REAL
// ===============================

app.get("/payload", (req, res) => {
    const ip = getIP(req);
    const token = req.query.token;

    if (isBlocked(ip)) {
        return res
            .status(403)
            .type("text/plain")
            .send("Acceso denegado");
    }

    if (!token || typeof token !== "string") {
        return res
            .status(403)
            .type("text/plain")
            .send("Acceso denegado");
    }

    const data = tokens.get(token);

    if (!data) {
        return res
            .status(403)
            .type("text/plain")
            .send("Acceso denegado");
    }

    // Token asociado a otra IP
    if (data.ip !== ip) {
        tokens.delete(token);
        blockIP(ip, 60);

        return res
            .status(403)
            .type("text/plain")
            .send("Acceso denegado");
    }

    // Token expirado
    if (data.expires <= now()) {
        tokens.delete(token);

        return res
            .status(403)
            .type("text/plain")
            .send("Acceso denegado");
    }

    // Token reutilizado
    if (data.used) {
        tokens.delete(token);

        return res
            .status(403)
            .type("text/plain")
            .send("Acceso denegado");
    }

    // Consumir token
    data.used = true;

    // Eliminarlo después de usarlo
    tokens.delete(token);

    res.setHeader(
        "Content-Type",
        "text/plain; charset=utf-8"
    );

    res.setHeader(
        "Cache-Control",
        "no-store, no-cache, must-revalidate"
    );

    res.status(200).send(SCRIPT);
});

// ===============================
// RUTAS DESCONOCIDAS
// ===============================

app.use((req, res) => {
    res.status(404)
        .type("text/plain")
        .send("No encontrado");
});

// ===============================
// SERVIDOR
// ===============================

app.listen(PORT, "0.0.0.0", () => {
    console.log(`Zyren Loader iniciado en puerto ${PORT}`);
});
