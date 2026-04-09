#!/usr/bin/env bun

import fs from "node:fs"
import path from "node:path"

const [rootDir, version] = process.argv.slice(2)

if (!rootDir || !version) {
  console.error("Usage: apply-opencode-tps-patch.mjs <opencode-root> <version>")
  process.exit(1)
}

function read(file) {
  return fs.readFileSync(file, "utf8")
}

function write(file, content) {
  fs.writeFileSync(file, content)
}

function fail(message) {
  console.error(`Error: ${message}`)
  process.exit(1)
}

function replaceOnce(source, needle, replacement, label) {
  if (!source.includes(needle)) fail(`Could not find ${label}`)
  return source.replace(needle, replacement)
}

function replaceRegexOnce(source, regex, replacer, label) {
  if (!regex.test(source)) fail(`Could not find ${label}`)
  return source.replace(regex, replacer)
}

function patchPromptIndexTsx(file) {
  let source = read(file)

  if (!source.includes("function estimateStreamTokens(delta: string)")) {
    const helpers = `

function estimateStreamTokens(delta: string) {
  return Math.max(1, Math.ceil(Buffer.byteLength(delta, "utf8") / 4))
}

function formatTps(value: number) {
  if (!Number.isFinite(value) || value <= 0) return undefined
  if (value >= 100) return \`\${Math.round(value)} TPS\`
  if (value >= 10) return \`\${value.toFixed(1)} TPS\`
  return \`\${value.toFixed(2)} TPS\`
}

type StreamSample = { at: number; tokens: number }

const STREAM_WINDOW_MS = 15_000
const ACTIVE_GAP_MS = 1_250
const LIVE_STALE_MS = 1_500
const SINGLE_SAMPLE_MS = 1_000
const MAX_MESSAGE_SAMPLES = 4_096
const MAX_TRACKED_MESSAGES = 24

function activeDurationMs(samples: StreamSample[], tailAt?: number) {
  if (samples.length === 0) return 0
  if (samples.length === 1) {
    const tailDuration = tailAt ? Math.max(0, tailAt - samples[0].at) : SINGLE_SAMPLE_MS
    return Math.min(Math.max(tailDuration, 250), SINGLE_SAMPLE_MS)
  }

  let duration = 0
  for (let i = 1; i < samples.length; i++) {
    duration += Math.min(Math.max(0, samples[i].at - samples[i - 1].at), ACTIVE_GAP_MS)
  }

  if (tailAt) {
    duration += Math.min(Math.max(0, tailAt - samples[samples.length - 1].at), ACTIVE_GAP_MS)
  }

  return Math.max(duration, SINGLE_SAMPLE_MS)
}

function truncateTrackedMessages(stats: Record<string, StreamSample[]>) {
  const entries = Object.entries(stats)
  if (entries.length <= MAX_TRACKED_MESSAGES) return stats
  const trimmed = entries
    .sort((a, b) => (b[1][b[1].length - 1]?.at ?? 0) - (a[1][a[1].length - 1]?.at ?? 0))
    .slice(0, MAX_TRACKED_MESSAGES)
  return Object.fromEntries(trimmed)
}
`

    source = replaceRegexOnce(
      source,
      /function randomIndex\(count: number\) \{[\s\S]*?\n\}/,
      (match) => `${match}${helpers}`,
      "randomIndex helper block",
    )
  }

  const usageStart = source.indexOf("  const usage = createMemo(() => {")
  const storeStart = source.indexOf("  const [store, setStore] = createStore<")
  if (usageStart === -1 || storeStart === -1 || storeStart <= usageStart) {
    fail("Could not locate usage/store block in prompt footer")
  }

  const usageBlock = `  const sessionMessages = createMemo(() => {
    if (!props.sessionID) return []
    return sync.data.message[props.sessionID] ?? []
  })

  const activeAssistantMessage = createMemo(() => {
    return sessionMessages().findLast((item): item is AssistantMessage => item.role === "assistant" && !item.time.completed)
  })

  const [streamSamples, setStreamSamples] = createSignal<StreamSample[]>([])
  const [messageSamples, setMessageSamples] = createSignal<Record<string, StreamSample[]>>({})
  const [clock, setClock] = createSignal(Date.now())

  function pruneSamples(now = Date.now()) {
    setStreamSamples((samples) => samples.filter((sample) => now - sample.at <= STREAM_WINDOW_MS))
  }

  function appendSample(messageID: string, sample: StreamSample) {
    const now = sample.at
    setStreamSamples((samples) => [...samples.filter((item) => now - item.at <= STREAM_WINDOW_MS), sample])
    setMessageSamples((stats) => {
      const next = {
        ...stats,
        [messageID]: [...(stats[messageID] ?? []), sample].slice(-MAX_MESSAGE_SAMPLES),
      }
      return truncateTrackedMessages(next)
    })
  }

  sdk.event.on("message.part.delta", (evt) => {
    if (!props.sessionID) return
    if (evt.properties.field !== "text") return
    if (evt.properties.messageID !== activeAssistantMessage()?.id) return
    const parts = sync.data.part[evt.properties.messageID]
    const part = parts?.find((item) => item.id === evt.properties.partID)
    if (!part) return
    if (part.type !== "text" && part.type !== "reasoning") return
    const now = Date.now()
    appendSample(evt.properties.messageID, { at: now, tokens: estimateStreamTokens(evt.properties.delta) })
  })

  sdk.event.on("message.updated", (evt) => {
    if (evt.properties.info.sessionID !== props.sessionID) return
    if (evt.properties.info.role !== "assistant") return
    if (evt.properties.info.time.completed) {
      pruneSamples(evt.properties.info.time.completed)
    }
  })

  onMount(() => {
    const timer = setInterval(() => {
      setClock(Date.now())
      pruneSamples()
    }, 1000)

    onCleanup(() => clearInterval(timer))
  })

  const usage = createMemo(() => {
    if (!props.sessionID) return
    const msg = sessionMessages()
    const last = msg.findLast((item): item is AssistantMessage => item.role === "assistant" && item.tokens.output > 0)
    if (!last) return

    const totalTokens =
      last.tokens.input + last.tokens.output + last.tokens.reasoning + last.tokens.cache.read + last.tokens.cache.write
    if (totalTokens <= 0) return

    const model = sync.data.provider.find((item) => item.id === last.providerID)?.models[last.modelID]
    const pct = model?.limit.context ? \`\${Math.round((totalTokens / model.limit.context) * 100)}%\` : undefined
    const cost = msg.reduce((sum, item) => sum + (item.role === "assistant" ? item.cost : 0), 0)
    const user = msg.find((item) => item.role === "user" && item.id === last.parentID)
    const start = user?.time.created ?? last.time.created
    const end = last.time.completed ?? last.time.created
    const sampleWindow = messageSamples()[last.id] ?? []
    const activeMs = activeDurationMs(sampleWindow)
    const wallMs = end > start ? end - start : 0
    const durationSeconds = (activeMs > 0 ? activeMs : wallMs) / 1000
    const exactTotalTps = durationSeconds > 0 ? totalTokens / durationSeconds : 0
    const exactOutputTps = durationSeconds > 0 ? last.tokens.output / durationSeconds : 0
    return {
      context: pct ? \`\${Locale.number(totalTokens)} (\${pct})\` : Locale.number(totalTokens),
      cost: cost > 0 ? money.format(cost) : undefined,
      totalTps: formatTps(exactTotalTps),
      outputTps: formatTps(exactOutputTps),
    }
  })

  const liveTps = createMemo(() => {
    clock()
    if (status().type === "idle") return undefined
    const samples = streamSamples()
    if (samples.length === 0) return undefined
    const now = Date.now()
    const relevant = samples.filter((sample) => now - sample.at <= STREAM_WINDOW_MS)
    if (relevant.length === 0) return undefined
    const lastSample = relevant[relevant.length - 1]
    if (!lastSample || now - lastSample.at > LIVE_STALE_MS) return undefined
    const total = relevant.reduce((sum, sample) => sum + sample.tokens, 0)
    const durationSeconds = activeDurationMs(relevant, now) / 1000
    if (durationSeconds <= 0) return undefined
    return formatTps(total / durationSeconds)
  })

`

  source = `${source.slice(0, usageStart)}${usageBlock}${source.slice(storeStart)}`

  source = replaceRegexOnce(
    source,
    /\[item\(\)\.context, item\(\)\.cost\]\s*\.filter\(Boolean\)\s*\.join\(" · "\)/,
    () => `[liveTps() ? \`~\${liveTps()}\` : item().outputTps, item().context, item().cost]
                            .filter(Boolean)
                            .join(" · ")`,
    "footer usage expression",
  )

  write(file, source)
}

function patchIndexTs(file) {
  let source = read(file)
  if (source.includes("process.env.OPENCODE_LAUNCH_CWD")) return

  const block = `if (process.env.OPENCODE_LAUNCH_CWD) {
  try {
    process.chdir(process.env.OPENCODE_LAUNCH_CWD)
  } catch (error) {
    process.stderr.write(
      \`Failed to change directory to \${process.env.OPENCODE_LAUNCH_CWD}: \${error instanceof Error ? error.message : String(error)}\${EOL}\`,
    )
    process.exit(1)
  }
}

`

  source = replaceOnce(source, 'process.on("unhandledRejection", (e) => {', `${block}process.on("unhandledRejection", (e) => {`, "unhandledRejection handler")
  write(file, source)
}

function patchMetaTs(file) {
  let source = read(file)
  source = replaceRegexOnce(
    source,
    /export const VERSION = typeof OPENCODE_VERSION === "string" \? OPENCODE_VERSION : "[^"]+"/,
    `export const VERSION = typeof OPENCODE_VERSION === "string" ? OPENCODE_VERSION : "${version}"`,
    "VERSION export",
  )
  source = replaceRegexOnce(
    source,
    /export const CHANNEL = typeof OPENCODE_CHANNEL === "string" \? OPENCODE_CHANNEL : "[^"]+"/,
    'export const CHANNEL = typeof OPENCODE_CHANNEL === "string" ? OPENCODE_CHANNEL : "latest"',
    "CHANNEL export",
  )
  write(file, source)
}

const promptFile = path.join(rootDir, "packages/opencode/src/cli/cmd/tui/component/prompt/index.tsx")
const indexFile = path.join(rootDir, "packages/opencode/src/index.ts")
const metaFile = path.join(rootDir, "packages/opencode/src/installation/meta.ts")

for (const file of [promptFile, indexFile, metaFile]) {
  if (!fs.existsSync(file)) fail(`Missing expected file: ${file}`)
}

patchPromptIndexTsx(promptFile)
patchIndexTs(indexFile)
patchMetaTs(metaFile)

console.log(`Patched OpenCode ${version} with TPS meter`)
