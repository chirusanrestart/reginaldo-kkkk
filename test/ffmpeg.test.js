import test from "node:test";
import assert from "node:assert/strict";
import { parseArguments } from "../ffmpeg.js";

test("usa os padrões do conversor", () => {
  const result = parseArguments(["entrada.mp4", "saida.mp4"]);
  assert.equal(result.codec, "h264");
  assert.equal(result.resolution, "original");
  assert.equal(result.engine, "auto");
});

test("aceita codec, resolução e motor personalizados", () => {
  const result = parseArguments([
    "in.mkv", "out.mp4", "--codec", "hevc",
    "--resolution", "720p", "--bitrate", "1800k", "--engine", "gpu"
  ]);
  assert.equal(result.codec, "hevc");
  assert.equal(result.resolution, "720p");
  assert.equal(result.bitrate, "1800k");
  assert.equal(result.engine, "gpu");
});

test("rejeita codec desconhecido", () => {
  assert.throws(() => parseArguments(["a.mp4", "b.mp4", "--codec", "mpeg4"]), /Codec inválido/);
});

test("rejeita bitrate inválido", () => {
  assert.throws(() => parseArguments(["a.mp4", "b.mp4", "--bitrate", "rápido"]), /bitrate inválido/);
});

test("reconhece o modo de capacidades", () => {
  assert.deepEqual(parseArguments(["--capabilities"]), { capabilities: true });
});
