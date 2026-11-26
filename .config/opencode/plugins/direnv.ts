import { Plugin } from "@opencode/plugin"
import { existsSync } from "node:fs"
import { homedir } from "node:os"
import { dirname, join, resolve } from "node:path"

const workEnvrc = join(homedir(), ".envrc")
const profileKeys = [
  "GH_TOKEN",
  "GITHUB_TOKEN",
  "WORKSTATION_PROFILE",
  "CLAUDE_CONFIG_DIR",
  "CURSOR_CONFIG_DIR",
  "CURSOR_API_KEY",
  "MOMENCE_USER_EMAIL",
  "MOMENCE_USER_PASSWORD",
  "DEV_DB_HOST",
  "DEV_DB_PORT",
  "DEV_DB_USER",
  "DEV_DB_NAME",
  "DEV_DB_PASSWORD",
  "DEV_DB_URL",
] as const

type Environment = Record<string, string | undefined>

function findEnvrcInParents(directory: string): string | undefined {
  let current = resolve(directory)

  while (true) {
    if (existsSync(join(current, ".envrc"))) return current
    const parent = dirname(current)
    if (parent === current) return undefined
    current = parent
  }
}

async function findEnvrc(directory: string): Promise<string | undefined> {
  const direct = findEnvrcInParents(directory)

  // Linked worktrees can live outside the canonical checkout. Prefer the
  // profile that owns the repository over a more generic home-level fallback.
  const child = Bun.spawn(["git", "-C", directory, "worktree", "list", "--porcelain"], {
    stdout: "pipe",
    stderr: "pipe",
  })
  const [stdout, , exitCode] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ])
  if (exitCode !== 0) return direct

  const mainWorktree = stdout.split("\n").find((line) => line.startsWith("worktree "))
  if (!mainWorktree) return direct

  const canonical = findEnvrcInParents(mainWorktree.slice("worktree ".length))
  if (!canonical) return direct
  if (!direct) return canonical

  // A project-local .envrc inside the worktree is more specific than the
  // canonical checkout's workspace profile.
  return canonical.split("/").length > direct.split("/").length ? canonical : direct
}

function parseEnvironment(output: string): Record<string, string> {
  const environment: Record<string, string> = {}

  for (const entry of output.split("\0")) {
    if (!entry) continue
    const separator = entry.indexOf("=")
    if (separator <= 0) continue
    environment[entry.slice(0, separator)] = entry.slice(separator + 1)
  }

  return environment
}

async function loadEnvironment(directory: string, base: Environment): Promise<Record<string, string>> {
  const envrc = await findEnvrc(directory)
  const command = envrc
    ? ["direnv", "exec", envrc, "/usr/bin/env", "-0"]
    : ["/bin/zsh", "-c", 'source "$1" && /usr/bin/env -0', "zsh", workEnvrc]

  const child = Bun.spawn(command, {
    cwd: directory,
    env: base,
    stdout: "pipe",
    stderr: "pipe",
  })
  const [stdout, , exitCode] = await Promise.all([
    new Response(child.stdout).text(),
    new Response(child.stderr).text(),
    child.exited,
  ])

  if (exitCode !== 0) {
    throw new Error(`Unable to load workstation profile for ${directory} (exit ${exitCode})`)
  }

  const environment = parseEnvironment(stdout)
  if (base.PWD !== undefined) environment.PWD = base.PWD
  return environment
}

function replaceEnvironment(target: Environment, source: Record<string, string>): void {
  for (const key of Object.keys(target)) delete target[key]
  Object.assign(target, source)
}

export default Plugin.define({
  id: "workstation.direnv",
  async setup(ctx) {
    const environment = await loadEnvironment(ctx.location.project.canonical, process.env)

    await ctx.mcp.transform((editor) => {
      for (const [name, config] of editor.list()) {
        if (name === "github" && config.type === "remote" && environment.GH_TOKEN) {
          editor.set(name, {
            ...config,
            headers: {
              ...config.headers,
              Authorization: `Bearer ${environment.GH_TOKEN}`,
            },
          })
          continue
        }

        if (config.type === "local") {
          const variables = { ...config.environment }
          for (const key of profileKeys) {
            if (environment[key] === undefined) delete variables[key]
            else variables[key] = environment[key]
          }
          editor.set(name, { ...config, environment: variables })
        }
      }
    })

    await ctx.shell.hook("create.before", async (event) => {
      const loaded = await loadEnvironment(event.cwd, event.env)
      replaceEnvironment(event.env, loaded)
    })
  },
})
