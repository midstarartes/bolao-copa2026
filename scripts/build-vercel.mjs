import { cp, mkdir, rm } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, "..");
const distDir = path.join(rootDir, "dist");

await rm(distDir, { recursive: true, force: true });
await mkdir(distDir, { recursive: true });

const copyTargets = [
  "index.html",
  "design-lab.html",
  "public"
];

for (const target of copyTargets) {
  await cp(path.join(rootDir, target), path.join(distDir, target), {
    recursive: true
  });
}

console.log("Static build ready in dist/");
