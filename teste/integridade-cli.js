// Imprime OK ou FALHA para a soma de integridade NSIS do arquivo (a mesma conta do programa-caixa/integridade.js).
const fs = require("node:fs");
const { integridadeNsis } = require("./integridade");
const r = integridadeNsis(fs.readFileSync(process.argv[2]));
console.log(r.nsis && r.ok ? "OK" : "FALHA");
