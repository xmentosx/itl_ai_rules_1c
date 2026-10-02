import assert from "node:assert/strict"
import { createHash } from "node:crypto"
import { mkdir, readFile, readdir, writeFile } from "node:fs/promises"
import { join, relative } from "node:path"
import { pathToFileURL } from "node:url"

const [pluginPath, fixtureRoot] = process.argv.slice(2)
const { OneCRulesPlugin } = await import(pathToFileURL(pluginPath).href)

async function snapshot(root) {
  const entries = []
  async function visit(directory) {
    for (const entry of await readdir(directory, { withFileTypes: true })) {
      const path = join(directory, entry.name)
      const name = relative(root, path)
      if (entry.isDirectory()) {
        entries.push([name, "directory"])
        await visit(path)
      } else {
        entries.push([name, createHash("sha256").update(await readFile(path)).digest("hex")])
      }
    }
  }
  await visit(root)
  return entries.sort(([left], [right]) => left.localeCompare(right))
}

async function fixture(name, managed, protocol) {
  const root = join(fixtureRoot, name)
  await mkdir(join(root, "src", "cf"), { recursive: true })
  await writeFile(join(root, "src", "cf", "Configuration.xml"), "<Configuration />\n")
  await writeFile(join(root, "USER-RULES.md"), "User-owned rules remain unchanged.\n")
  if (managed) {
    await mkdir(join(root, ".agent-1c"), { recursive: true })
    await writeFile(join(root, ".agent-1c", "project.json"), "{}\n")
    if (protocol) {
      const helperRoot = join(root, ".agents", "skills", "1c-workflow", "scripts")
      await mkdir(helperRoot, { recursive: true })
      await writeFile(join(root, ".agent-1c", "dependency-lock.json"), JSON.stringify({
        dependencies: { aiRules1c: { commit: "a".repeat(40) } },
      }))
      await writeFile(join(helperRoot, "plugin-dispatch.json"), JSON.stringify({
        protocolVersion: 1, owner: "itl-workflow",
      }))
      await writeFile(join(helperRoot, "agent-1c.ps1"),
        '[IO.File]::WriteAllText((Join-Path $PSScriptRoot "called"), "unexpected helper call")')
    }
  }
  return root
}

const proof = { hosts: [] }
const originalWarn = console.warn
const oldKiloCli = process.env.KILO_CLI
const oldKilocode = process.env.KILOCODE
try {
  for (const host of ["opencode", "kilocode"]) {
    delete process.env.KILO_CLI
    delete process.env.KILOCODE
    if (host === "kilocode") process.env.KILO_CLI = "1"
    const failureRoot = await fixture(`${host} broken проект`, true, false)
    const failedBefore = await snapshot(failureRoot)
    const hooks = await OneCRulesPlugin({ directory: failureRoot })
    await hooks.event({ event: { type: "session.updated" } })
    await hooks.event({})
    assert.deepEqual(await snapshot(failureRoot), failedBefore)

    const warnings = []
    console.warn = (message) => warnings.push(message)
    let failure
    try {
      await hooks.event({ event: { type: "session.created" } })
    } catch (error) {
      failure = error
    } finally {
      console.warn = originalWarn
    }
    assert.ok(failure instanceof Error, `${host}: a real wrapper exit 1 must reject the event`)
    assert.equal(failure.name, "OneCRulesEnsureError")
    assert.equal(failure.code, "ONEC_RULES_ENSURE_FAILED")
    assert.equal(failure.exitCode, 1)
    assert.match(failure.diagnostic, /ITL_PLUGIN_PROTOCOL_UNAVAILABLE/)
    assert.match(failure.diagnostic, /\/itl-update-workflow/)
    assert.match(failure.message, /code 1/)
    assert.equal(warnings.length, 1)
    assert.equal(warnings[0], failure.message)
    assert.ok(failure.diagnostic.length <= 8192)
    assert.doesNotMatch(failure.diagnostic, /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/)
    assert.deepEqual(await snapshot(failureRoot), failedBefore)

    for (const managed of [false, true]) {
      const root = await fixture(`${host} ${managed ? "managed" : "standalone"} проект`, managed, true)
      const before = await snapshot(root)
      const successHooks = await OneCRulesPlugin({ directory: root })
      await successHooks.event({ event: { type: "session.created" } })
      assert.deepEqual(await snapshot(root), before, `${host}: session ensure must not mutate the project`)
    }
    const unicodeRoot = await fixture(`${host} неверный протокол`, true, true)
    const protocolPath = join(unicodeRoot, ".agents", "skills", "1c-workflow", "scripts", "plugin-dispatch.json")
    await writeFile(protocolPath, '{"protocolVersion":2,"owner":"itl-workflow"}')
    const unicodeBefore = await snapshot(unicodeRoot)
    const unicodeHooks = await OneCRulesPlugin({ directory: unicodeRoot })
    let unicodeFailure
    console.warn = () => {}
    try {
      await unicodeHooks.event({ event: { type: "session.created" } })
    } catch (error) {
      unicodeFailure = error
    } finally {
      console.warn = originalWarn
    }
    assert.equal(unicodeFailure?.exitCode, 1)
    assert.match(unicodeFailure.diagnostic, /ITL_PLUGIN_PROTOCOL_UNSUPPORTED/)
    assert.ok(unicodeFailure.diagnostic.includes(protocolPath), `${host}: diagnostic must preserve the exact Unicode path: ${unicodeFailure.diagnostic}`)
    assert.deepEqual(await snapshot(unicodeRoot), unicodeBefore)
    proof.hosts.push({
      host, unrelatedEventPassed: true, standaloneReadOnlyPassed: true, managedReadOnlyPassed: true, unicodeDiagnosticPassed: true,
      failure: { code: failure.code, exitCode: failure.exitCode, diagnostic: failure.diagnostic },
    })
  }
} finally {
  console.warn = originalWarn
  if (oldKiloCli === undefined) delete process.env.KILO_CLI
  else process.env.KILO_CLI = oldKiloCli
  if (oldKilocode === undefined) delete process.env.KILOCODE
  else process.env.KILOCODE = oldKilocode
}
console.log(JSON.stringify(proof))
