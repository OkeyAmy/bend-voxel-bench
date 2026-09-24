// Builds Bend programs and the C++ golden tool into build/.
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { homedir } from "node:os";

export const BEND = process.env.BEND ?? `${homedir()}/.bend/bin/bend`;
export const BUILD = "build";

// bend <src> -o build/<out>
export function bendBuild(src: string, out: string): void {
  mkdirSync(BUILD, { recursive: true });
  execFileSync(BEND, [src, "-o", `${BUILD}/${out}`], { stdio: "inherit", env: { ...process.env, BEND_NO_TELEMETRY: "1" } });
}

export function buildEngine(): void {
  bendBuild("engine/main.bend", "voxel");
}

// same flags as Luanti's Release build (src/CMakeLists.txt at 5.17.0)
export function buildGolden(): void {
  mkdirSync(BUILD, { recursive: true });
  execFileSync("g++", ["-O3", "-pipe", "-funroll-loops", "-fno-math-errno", "-fno-trapping-math",
    "-fno-signed-zeros", "-o", `${BUILD}/golden`, "tools/golden/golden.cpp"], { stdio: "inherit" });
}
