const express = require("express");
const sql = require("mssql"); // On utilise mssql pour Azure SQL
require('dotenv').config();

const app = express();
app.use(express.json());

// Configuration de la connexion Azure SQL
const sqlConfig = {
    user: 'bechardadmin',
    password: 'TonMotDePasse123!', // On sécurisera ça plus tard avec des secrets
    database: 'ecomdb',
    server: 'server-sql-bechard-final.database.windows.net',
    pool: { max: 10, min: 0, idleTimeoutMillis: 30000 },
    options: { encrypt: true, trustServerCertificate: false }
};

app.get("/", async (req, res) => {
    try {
        await sql.connect(sqlConfig);
        res.send("<h1>🚀 E-commerce Bechard opérationnel sur Azure AKS</h1><p>Status: Connecté à Azure SQL Database</p>");
    } catch (err) {
        res.status(500).send("Erreur de connexion : " + err.message);
    }
});

app.listen(3000, () => console.log("Serveur sur port 3000"));