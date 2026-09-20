const express = require("express");
const fs = require("fs");
const path = require("path");

const app = express();
const PORT = process.env.PORT || 3000;

const SCRIPT_PATH = path.join(__dirname, "script.lua");

let script;

try {
    script = fs.readFileSync(SCRIPT_PATH, "utf8");
} catch (err) {
    console.error("No se pudo cargar script.lua:", err);
    process.exit(1);
}

// Página principal: no muestra el script
app.get("/", (req, res) => {
    res.status(403).type("text/plain").send("Acceso denegado");
});

// Loader público
app.get("/loader", (req, res) => {
    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Cache-Control", "no-store");
    res.status(200).send(script);
});

// Cualquier otra ruta
app.use((req, res) => {
    res.status(404).type("text/plain").send("No encontrado");
});

app.listen(PORT, "0.0.0.0", () => {
    console.log(`Loader iniciado en el puerto ${PORT}`);
});
