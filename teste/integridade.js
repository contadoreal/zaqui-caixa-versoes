"use strict";
// O processo do Electron é CommonJS: `require` é o jeito dele carregar módulo.
/* eslint-disable @typescript-eslint/no-require-imports */
/**
 * A SOMA DE INTEGRIDADE DO NSIS (versão 1.2.0, 13/11/2026). É a conta que o Windows faz ao abrir
 * o instalador ou o desinstalador; quando ela não fecha, aparece "NSIS Error" e nada roda.
 * Foi assim que o desinstalador da 1.0.0 travou a instalação por cima (`instalador.nsh`).
 *
 * A regra (achada procurando, no desinstalador íntegro da 1.1.0, o trecho cujo CRC32 bate com o
 * guardado; depois conferida nos dois instaladores): CRC32 de TODO o arquivo a partir do byte 512
 * até 4 bytes antes do fim dos dados do NSIS; os 4 bytes finais guardam a soma.
 */
const zlib = require("node:zlib");

function integridadeNsis(b) {
  let i = -1;
  let inicio = -1;
  while ((i = b.indexOf("NullsoftInst", i + 1, "latin1")) >= 0) {
    if ((i - 8) % 512 === 0) {
      inicio = i - 8;
      break;
    }
  }
  if (inicio < 0) return { nsis: false };
  const total = b.readInt32LE(inicio + 24);
  const fim = inicio + total;
  if (fim > b.length || fim < 516) return { nsis: true, ok: false, motivo: "tamanho dos dados maior que o arquivo" };
  const guardado = b.readUInt32LE(fim - 4);
  const calculado = zlib.crc32(b.subarray(512, fim - 4)) >>> 0;
  return { nsis: true, ok: guardado === calculado, guardado, calculado };
}

module.exports = { integridadeNsis };
