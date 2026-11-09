//
//  export-marketplace-catalog.mjs
//  AriaLite
//
//  Created by Giovanni Michele on 23/10/26.
//
//  Esporta il catalogo del Marketplace della web (aria-web, `lib/marketplace` e `lib/agent-studio`) in un JSON
//  che l'app legge dal bundle: skill, connettori, plugin, workflow, agent pack, knowledge pack e full set,
//  con i prezzi e il contenuto completo di ogni full set. Il catalogo esiste solo nel frontend della web (il
//  backend ha solo i connettori), quindi si rigenera quando la web cambia:
//
//      node scripts/export-marketplace-catalog.mjs ~/Desktop/aria-web
//
//  Scrive `AriaLite/Admin/Marketplace/Resources/MarketplaceCatalog.json` (testi in inglese, come la web) e
//  `scripts/marketplace-strings.json`, l'elenco dei testi da tradurre: le traduzioni italiane stanno in
//  `MarketplaceCatalog.it.json` (testo inglese → italiano), e quelle che mancano restano in inglese.
//

import { createRequire } from "node:module"
import { execFileSync } from "node:child_process"
import { readdirSync, writeFileSync, existsSync, readFileSync, mkdirSync, rmSync } from "node:fs"
import { dirname, join, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const HERE = dirname(fileURLToPath(import.meta.url))
const WEB = resolve(process.argv[2] ?? join(HERE, "../../../aria-web"))
const OUT_DIR = join(HERE, "../AriaLite/Admin/Marketplace/Resources")
const BRANDS_DIR = join(HERE, "../AriaLite/Assets.xcassets/ConnectorBrands")

// aria-web usa pnpm: jiti (che esegue il TypeScript della web così com'è) sta nello store.
const pnpm = join(WEB, "node_modules/.pnpm")
const jitiDir = readdirSync(pnpm).find((d) => d.startsWith("jiti@"))
if (!jitiDir) throw new Error(`jiti non trovato in ${pnpm}: esegui pnpm install in aria-web`)
const require = createRequire(join(WEB, "package.json"))
const { createJiti } = require(join(pnpm, jitiDir, "node_modules/jiti/lib/jiti.cjs"))
const jiti = createJiti(join(WEB, "export.ts"), { alias: { "@": WEB }, interopDefault: true, jsx: true })
const load = (path) => jiti.import(join(WEB, path))

const catalog = await load("lib/marketplace/catalog.ts")
const connectors = await load("lib/agent-studio/connectors.ts")
const addons = await load("lib/agent-studio/customize-catalog.ts")
const templates = await load("lib/agent-studio/workflow-templates.ts")
const workflows = await load("lib/agent-studio/workflows.ts")
const model = await load("lib/agent-studio/model.ts")
const agentPacks = await load("lib/marketplace/agent-packs.ts")
const knowledgePacks = await load("lib/marketplace/knowledge-packs.ts")
const fullSets = await load("lib/marketplace/full-sets.ts")
const setContent = await load("lib/marketplace/full-set-content.ts")
const pricing = await load("lib/marketplace/pricing.ts")
const brands = await load("lib/agent-studio/connector-brands.tsx")

const iconName = (icon) => icon?.displayName ?? icon?.name ?? null
const clean = (object) => Object.fromEntries(Object.entries(object).filter(([, v]) => v !== undefined && v !== null))

/** Un passo di un workflow come lo scrive la pagina della web (`stepRow` in item-detail.tsx). */
function stepRow(step) {
  if (step.kind === "connector") {
    return { kind: "connector", title: step.capability, detail: connectors.connectorById(step.connectorId)?.name ?? step.connectorId, connectorId: step.connectorId }
  }
  if (step.kind === "agent") {
    return { kind: "agent", title: `${model.agentMeta(step.agentName).label} agent`, detail: step.task }
  }
  const action = step.actionType.replace(/_/g, " ")
  return { kind: "action", title: action.charAt(0).toUpperCase() + action.slice(1), detail: workflows.actionConfigSummary(step.config) }
}

function extras(item) {
  switch (item.kind) {
    case "connector": {
      const c = connectors.connectorById(item.sourceId)
      const brand = brands.brandIdentity(c.id)
      return {
        connector: clean({
          category: c.category,
          vendors: c.vendors,
          preview: connectors.isPreviewConnector(c),
          custom: c.custom ?? false,
          // Come si collega: `api-key` (MaintainX), `oauth`; `one-click` = l'owner lo abilita e ogni membro collega il suo account.
          auth: c.auth,
          setup: c.setup,
          endpoint: c.endpoint,
          orgFromConsent: c.orgFromConsent,
          brandHex: brand.hex ?? undefined,
          brandImage: brand.paths ? `ConnectorBrands/${c.id}` : undefined,
        }),
      }
    }
    case "skill":
      return {}
    case "plugin":
      return { plugin: { skills: addons.addonById(item.sourceId)?.bundles ?? [] } }
    case "workflow": {
      const t = templates.WORKFLOW_TEMPLATES.find((w) => w.id === item.sourceId)
      return { workflow: { trigger: workflows.describeTrigger(t.trigger), steps: t.steps.map(stepRow) } }
    }
    case "agent-pack": {
      const p = agentPacks.agentPackById(item.sourceId)
      return { agentPack: { agent: p.agent, role: p.role, rules: p.rules, terms: p.terms, skills: p.skills ?? [] } }
    }
    case "knowledge-pack": {
      const p = knowledgePacks.knowledgePackById(item.sourceId)
      return { knowledgePack: clean({ discipline: p.discipline, terms: p.terms, procedures: p.procedures, standards: p.standards }) }
    }
    case "full-set": {
      const set = fullSets.fullSetById(item.sourceId)
      const content = setContent.setContentOf(set.id)
      return {
        fullSet: {
          rules: set.rules,
          // `label`, non `kind`: `kind` è fra le chiavi che non si traducono.
          policies: set.policies.map((p) => ({ label: p.kind, text: p.text })),
          components: fullSets.fullSetContents(set),
          facts: content.facts,
          glossary: content.glossary.map((g) => ({ term: g.term, definition: g.definition })),
          procedures: content.procedures.map((p) => ({ title: p.title, steps: p.steps })),
          learned: content.learned.map((f) => ({ content: f.content, context: f.context, category: f.category })),
          alarms: content.alarms.map((a) => ({ code: a.code, description: a.description, category: a.category, typicalCauses: a.typical_causes, resolutionSteps: a.resolution_steps })),
          maintenancePlans: content.maintenancePlans.map((m) => ({ name: m.name, frequency: m.frequency, durationMinutes: m.estimated_duration_min, steps: m.steps })),
          spareParts: content.spareParts.map((p) => ({ code: p.code, name: p.name, category: p.category })),
          checklists: content.checklists.map((c) => ({ name: c.name, tasks: c.tasks })),
          documents: content.documents.map((d) => ({ title: d.title, note: d.note })),
        },
      }
    }
  }
}

const items = catalog.buildCatalog(connectors.CONNECTORS).map((item) => {
  const price = pricing.pricingOf(item)
  return clean({
    id: item.id,
    sourceId: item.sourceId,
    kind: item.kind,
    name: item.name,
    summary: item.summary,
    publisher: item.publisher,
    area: item.area,
    descriptor: item.descriptor,
    icon: iconName(item.icon),
    adds: item.adds,
    needs: item.needs?.length ? [...new Set(item.needs)] : undefined,
    isNew: item.isNew || undefined,
    keywords: item.kind === "full-set" ? undefined : item.keywords,
    machine: item.machine,
    monthlyPrice: price.tier === "paid" ? price.monthly : undefined,
    ...extras(item),
  })
})

let webCommit = "unknown"
try {
  webCommit = execFileSync("git", ["-C", WEB, "rev-parse", "--short", "HEAD"], { encoding: "utf8" }).trim()
} catch {}

const output = { source: `aria-web ${webCommit}`, items }
writeFileSync(join(OUT_DIR, "MarketplaceCatalog.json"), JSON.stringify(output, null, 2) + "\n")

// I testi da tradurre: tutto tranne id, codici, icone e valori che l'app traduce da sé (area, tipo, frequenza).
const SKIP = new Set(["id", "sourceId", "kind", "area", "icon", "needs", "components", "skills", "code", "connectorId", "frequency", "agent", "source", "custom", "preview", "auth", "setup", "endpoint", "brandHex", "brandImage"])
const strings = new Set()
const walk = (value, key) => {
  if (SKIP.has(key)) return
  if (typeof value === "string") strings.add(value)
  else if (Array.isArray(value)) value.forEach((v) => walk(v, key))
  else if (value && typeof value === "object") for (const [k, v] of Object.entries(value)) walk(v, k)
}
walk(items)
const list = [...strings].sort()
writeFileSync(join(HERE, "marketplace-strings.json"), JSON.stringify(list, null, 2) + "\n")

const itPath = join(OUT_DIR, "MarketplaceCatalog.it.json")
const translated = existsSync(itPath) ? JSON.parse(readFileSync(itPath, "utf8")) : {}
const missing = list.filter((s) => !(s in translated))
console.log(`${items.length} elementi da ${output.source}; ${list.length} testi, ${missing.length} senza traduzione italiana`)

// I loghi veri dei connettori (connector-brands.tsx della web: Simple Icons e le grafiche dei vendor) come SVG
// vettoriali nel catalogo degli asset. Monocromi = template, tinti dall'app con `brandHex`; a colori = originali,
// con la variante scura dove la web ne ha una (`.dark [data-brand-fill]` in globals.css).
const DARK_FILLS = { "maintainx-navy": "#4a7fb5", notion: "#ffffff" }
function svg(brand, dark) {
  const defs = (brand.gradients ?? []).map((g) =>
    `<linearGradient id="${g.id}" x1="${g.x1}" y1="${g.y1}" x2="${g.x2}" y2="${g.y2}" gradientUnits="userSpaceOnUse">` +
    g.stops.map((s) => `<stop offset="${s.offset}" stop-color="${s.color}"/>`).join("") + "</linearGradient>").join("")
  const paths = brand.paths.map((p) => {
    const fill = (dark && p.darkVariant && DARK_FILLS[p.darkVariant]) || p.fill || "#000000"
    return `<path d="${p.d}" fill="${fill}"${p.opacity !== undefined ? ` opacity="${p.opacity}"` : ""}/>`
  }).join("")
  return `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">` +
    (defs ? `<defs>${defs}</defs>` : "") + `<g${brand.transform ? ` transform="${brand.transform}"` : ""}>${paths}</g></svg>\n`
}
rmSync(BRANDS_DIR, { recursive: true, force: true })
mkdirSync(BRANDS_DIR, { recursive: true })
writeFileSync(join(BRANDS_DIR, "Contents.json"), JSON.stringify({ info: { author: "xcode", version: 1 }, properties: { "provides-namespace": true } }, null, 2) + "\n")
let marks = 0
for (const c of [...connectors.CONNECTORS, ...connectors.RETIRED_CONNECTORS]) {
  const brand = brands.brandIdentity(c.id)
  if (!brand.paths) continue
  const set = join(BRANDS_DIR, `${c.id}.imageset`)
  mkdirSync(set, { recursive: true })
  writeFileSync(join(set, `${c.id}.svg`), svg(brand, false))
  const images = [{ filename: `${c.id}.svg`, idiom: "universal" }]
  if (brand.paths.some((p) => p.darkVariant)) {
    writeFileSync(join(set, `${c.id}-dark.svg`), svg(brand, true))
    images.push({ appearances: [{ appearance: "luminosity", value: "dark" }], filename: `${c.id}-dark.svg`, idiom: "universal" })
  }
  const properties = { "preserves-vector-representation": true, ...(brand.fullColor ? {} : { "template-rendering-intent": "template" }) }
  writeFileSync(join(set, "Contents.json"), JSON.stringify({ images, info: { author: "xcode", version: 1 }, properties }, null, 2) + "\n")
  marks += 1
}
console.log(`${marks} loghi in Assets.xcassets/ConnectorBrands`)
