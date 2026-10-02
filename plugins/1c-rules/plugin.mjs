import { spawn } from "node:child_process"
import { dirname, join } from "node:path"
import { fileURLToPath } from "node:url"

const pluginRoot = dirname(fileURLToPath(import.meta.url))
const script = join(pluginRoot, "scripts", "invoke-install.ps1")

function hostTool() {
  if (process.env.KILO_CLI || process.env.KILOCODE) return "kilocode"
  return "opencode"
}

function runEnsure(projectRoot, tool) {
  return new Promise((resolve) => {
    const win = process.platform === "win32"
    const cmd = win ? "powershell.exe" : "pwsh"
    const args = ["-NoProfile"]
    if (win) args.push("-ExecutionPolicy", "Bypass")
    args.push("-File", script, "-Action", "ensure", "-Tool", tool, "-ProjectRoot", projectRoot)
    const child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"], windowsHide: true })
    let diagnostic = ""
    const collect = (chunk) => { diagnostic = (diagnostic + chunk).slice(-8192) }
    child.stdout.setEncoding("utf8")
    child.stderr.setEncoding("utf8")
    child.stdout.on("data", collect)
    child.stderr.on("data", collect)
    child.on("error", (error) => resolve({ code: 1, diagnostic: error.message }))
    child.on("close", (code) => resolve({ code: code ?? 1, diagnostic: diagnostic.trim() }))
  })
}

export const OneCRulesPlugin = async ({ directory }) => {
  return {
    event: async ({ event }) => {
      if (!event || event.type !== "session.created") return
      const root = directory || process.cwd()
      const result = await runEnsure(root, hostTool())
      if (result.code !== 0) {
        const diagnostic = result.diagnostic.slice(-8192).replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "").trim()
        const error = new Error(`[1c-rules] ONEC_RULES_ENSURE_FAILED: ensure exited with code ${result.code}. ${diagnostic || "No diagnostic output."}`)
        error.name = "OneCRulesEnsureError"
        error.code = "ONEC_RULES_ENSURE_FAILED"
        error.exitCode = result.code
        error.diagnostic = diagnostic
        // Legacy hosts may discard event promises; preserve the visible failure too.
        console.warn(error.message)
        throw error
      }
    },
  }
}

export default OneCRulesPlugin
