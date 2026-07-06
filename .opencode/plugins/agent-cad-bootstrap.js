import { existsSync } from "node:fs";
import path from "node:path";
import { spawnSync } from "node:child_process";

const bootstrapped = new Set();

function rootFrom(input) {
  return input?.worktree || input?.directory || process.cwd();
}

function runPowerShell(root, scriptName, args = []) {
  const scriptPath = path.join(root, scriptName);
  return spawnSync(
    "powershell.exe",
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", scriptPath, ...args],
    {
      cwd: root,
      encoding: "utf8",
      windowsHide: true,
      env: {
        ...process.env,
        PYTHONUTF8: "1",
      },
    }
  );
}

function writeLog(root, message) {
  const timestamp = new Date().toISOString();
  console.log(`[agent-cad bootstrap ${timestamp}] ${root}: ${message}`);
}

export const AgentCadBootstrap = async (input) => {
  const hooks = {
    "shell.env": async (_input, output) => {
      output.env.PYTHONUTF8 = "1";
    },
  };

  const root = path.resolve(rootFrom(input));
  if (bootstrapped.has(root)) {
    return hooks;
  }
  bootstrapped.add(root);

  if (process.env.AGENT_CAD_BOOTSTRAP === "0") {
    writeLog(root, "skipped because AGENT_CAD_BOOTSTRAP=0");
    return hooks;
  }

  if (!existsSync(path.join(root, "doctor-agent-cad.ps1")) || !existsSync(path.join(root, "setup-agent-cad.ps1"))) {
    return hooks;
  }

  const doctor = runPowerShell(root, "doctor-agent-cad.ps1", ["-Json"]);
  if (doctor.status === 0) {
    writeLog(root, "doctor passed");
    return hooks;
  }

  writeLog(root, "doctor reported missing setup; running setup-agent-cad.ps1");
  const setup = runPowerShell(root, "setup-agent-cad.ps1", [
    "-InstallDeps",
    "-InstallViewerDeps",
    "-InstallPlaywright",
  ]);

  if (setup.status !== 0) {
    const detail = [setup.stdout, setup.stderr].filter(Boolean).join("\n").trim();
    throw new Error(
      [
        "agent-cad automatic setup failed.",
        "Run .\\doctor-agent-cad.ps1 for details, then .\\setup-agent-cad.ps1 -InstallDeps -InstallViewerDeps -InstallPlaywright after fixing the blocker.",
        detail,
      ].filter(Boolean).join("\n")
    );
  }

  writeLog(root, "automatic setup completed");
  return hooks;
};
