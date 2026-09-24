// Builds Bend programs and the C++ golden tool into build/.
import { execFileSync } from "node:child_process";
import { mkdirSync } from "node:fs";
import { homedir } from "node:os";

export const BEND = process.env.BEND ?? `${homedir()}/.bend/bin/bend`;
export const BUILD = "build";

// Bend's checker has no work limit (bendlang/bend#1041): a type error can make it
// expand a term exponentially until the machine freezes. Every bend call runs in
// its own cgroup with a memory cap, no swap, and a timeout, so it gets killed instead.
export const BEND_CAP = ["systemd-run", "--user", "--scope", "-q", "-p", "MemoryMax=4G", "-p", "MemorySwapMax=0", "--", "timeout", "300"];

// bend <src> -o build/<out>
export function bendBuild(src: string, out: string): void {
  mkdirSync(BUILD, { recursive: true });
  const [cmd, ...pre] = BEND_CAP;
  execFileSync(cmd, [...pre, BEND, src, "-o", `${BUILD}/${out}`], { stdio: "inherit", env: { ...process.env, BEND_NO_TELEMETRY: "1" } });
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
