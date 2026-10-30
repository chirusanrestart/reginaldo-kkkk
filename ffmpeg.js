#!/usr/bin/env node
import { spawn } from "node:child_process";
import { access } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const SCRIPT = path.join(ROOT, "convert.sh");

const HELP = `
Chiru Converter 0.1.0

Uso:
  node ffmpeg.js <entrada> <saida> [opções]
  node ffmpeg.js --capabilities

Opções:
  --codec <h264|hevc|av1|copy>       Codec de vídeo (padrão: h264)
  --resolution <original|480p|720p|1080p|1440p|2160p|LARGURAxALTURA>
  --bitrate <valor>                 Bitrate de vídeo, ex.: 2500k ou 4M
  --audio-bitrate <valor>           Bitrate de áudio (padrão: 128k)
  --engine <auto|gpu|cpu>           Motor de codificação (padrão: auto)
  --help                            Mostra esta ajuda

Exemplo:
  node ffmpeg.js video.mkv convertido.mp4 --codec hevc --resolution 720p --bitrate 2M --engine auto
`;

const ALLOWED = {
  codec: new Set(["h264", "hevc", "av1", "copy"]),
  resolution: new Set(["original", "480p", "720p", "1080p", "1440p", "2160p"]),
  engine: new Set(["auto", "gpu", "cpu"])
};

export function parseArguments(args) {
  if (args.includes("--help") || args.length === 0) return { help: true };
  if (args.length === 1 && args[0] === "--capabilities") return { capabilities: true };

  const [input, output, ...rest] = args;
  if (!input || !output || input.startsWith("--") || output.startsWith("--")) {
    throw new Error("Informe os arquivos de entrada e saída.");
  }

  const options = {
    input,
    output,
    codec: "h264",
    resolution: "original",
    bitrate: "2M",
    audioBitrate: "128k",
    engine: "auto"
  };

  const keys = {
    "--codec": "codec",
    "--resolution": "resolution",
    "--bitrate": "bitrate",
    "--audio-bitrate": "audioBitrate",
    "--engine": "engine"
  };

  for (let i = 0; i < rest.length; i++) {
    const key = rest[i];
    const name = keys[key];
    if (!name) throw new Error(`Opção desconhecida: ${key}`);
    const value = rest[++i];
    if (!value || value.startsWith("--")) throw new Error(`Falta o valor de ${key}`);
    options[name] = value;
  }

  if (!ALLOWED.codec.has(options.codec)) throw new Error("Codec inválido.");
  if (!ALLOWED.resolution.has(options.resolution) && !/^\d{2,5}x\d{2,5}$/.test(options.resolution)) {
    throw new Error("Resolução inválida. Use original, 720p ou largura x altura.");
  }
  if (!ALLOWED.engine.has(options.engine)) throw new Error("Motor inválido.");
  for (const [label, value] of [["bitrate", options.bitrate], ["bitrate de áudio", options.audioBitrate]]) {
    if (!/^\d+(?:\.\d+)?[kKmM]?$/.test(value)) throw new Error(`Valor de ${label} inválido.`);
  }
  if (options.codec === "copy" && (options.resolution !== "original" || options.bitrate !== "2M")) {
    throw new Error("O modo copy não recodifica. Use resolução original e não informe --bitrate.");
  }
  return options;
}

function runShell(args) {
  return new Promise((resolve, reject) => {
    const child = spawn("bash", [SCRIPT, ...args], { stdio: "inherit" });
    child.once("error", reject);
    child.once("close", code => code === 0 ? resolve() : reject(new Error(`Conversão encerrada com código ${code}`)));
  });
}

export async function main(args = process.argv.slice(2)) {
  let options;
  try {
    options = parseArguments(args);
  } catch (error) {
    console.error(`Erro: ${error.message}\n\nUse --help para ver as opções.`);
    process.exitCode = 2;
    return;
  }

  if (options.help) {
    console.log(HELP);
    return;
  }
  if (options.capabilities) {
    await runShell(["--capabilities"]);
    return;
  }

  try {
    await access(options.input);
    await runShell([
      options.input,
      options.output,
      options.codec,
      options.resolution,
      options.bitrate,
      options.audioBitrate,
      options.engine
    ]);
  } catch (error) {
    console.error(`Erro: ${error.message}`);
    process.exitCode = 1;
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(path.resolve(process.argv[1])).href) {
  await main();
}
