-- Icon COMPOSER (prototype of the permanent system in docs/art-assets.md,
-- "The permanent icon system — compose, don't commission").
--
--     & "E:\LOVE\lovec.exe" . icon-compose        # render the demo spread (one per family + type)
--     & "E:\LOVE\lovec.exe" . icon-compose all     # ... every item blueprint
--
-- Where icon-build draws ONE game-icons glyph per asset, this draws the icon as a pure function of
-- the tags the blueprint already declares -- exactly the way shaders/field.lua draws a hazard from
-- its fire/ice tag. Four layers, four data channels, none of them a commission:
--
--   1. BASE    the family silhouette (Item.archetype -> FAMILY_BASE) -- 15 shapes cover every weapon;
--              a typeless item (ability/armor/utility/material) falls back to TYPE_BASE.
--   2. TINT    the base is recoloured by the item's element/strike tag (ELEMENT_TINT).
--   3. FRAME   a rounded border in the item's CLASS colour (the vendor shelf), thickening with tier.
--   4. BADGE   a corner disc in the item's TYPE colour, and `repRank` tier pips along the bottom.
--
-- The 15 base slugs are canonical game-icons picks (reuse, not commission -- the decision recorded in
-- the doc). Output lands under vendor/compose-preview/ -- gitignored, and deliberately NOT assets/, so
-- a prototype run can never overwrite the shipped icon set. When this graduates it writes assets/ like
-- icon-build and becomes the fourth pipeline verb.

local Registry = require("models.registry")
local Item = require("models.item")

local M = {}

local RESVG = "vendor/bin/resvg.exe"
local ICON_ROOT = "vendor/game-icons"
local OUT_ROOT = "vendor/compose-preview"
local RENDER_SIZE = 256 -- larger than icon-build's 128: a composed icon has a frame and badge to keep crisp
local BG_PATH = '<path d="M0 0h512v512H0z"/>'

-- 1. BASE -- one canonical game-icons silhouette per weapon family. These are the ~15 shapes the whole
-- item catalogue reduces to; verified present in the vendored set.
local FAMILY_BASE = {
    sword = "lorc/broadsword",
    greatsword = "delapouite/two-handed-sword",
    axe = "lorc/battle-axe",
    mace = "lorc/spiked-mace",
    hammer = "delapouite/thor-hammer",
    dagger = "lorc/broad-dagger",
    spear = "lorc/spear-hook",
    bow = "delapouite/bow-arrow",
    longbow = "lorc/high-shot",
    staff = "lorc/wizard-staff",
    wand = "lorc/crystal-wand",
    shield = "delapouite/cross-shield",
    censer = "lorc/incense",
    unarmed = "lorc/fist",
    natural = "delapouite/claws",
}

-- ... and a fallback base for the typeless items (an ability, a charm, a flask own no weapon family).
local TYPE_BASE = {
    ability = "lorc/magic-swirl",
    armor = "lorc/breastplate",
    utility = "lorc/round-bottom-flask",
    material = "lorc/gems",
}
local DEFAULT_BASE = "lorc/gems"

-- 2. TINT -- element/strike -> foreground colour. Scanned against the item's tags in this table's
-- favour: an element wins over the physical/melee mechanics tags, which name no colour and are absent
-- here. A physical strike (slash/pierce/blunt) or no element at all lands on steel.
local ELEMENT_TINT = {
    fire = "#ef7d4a", burn = "#ef7d4a",
    ice = "#7fc6ec", frost = "#7fc6ec",
    lightning = "#f3d24a", shock = "#f3d24a",
    holy = "#f2e6a8", radiant = "#f2e6a8", light = "#f2e6a8",
    shadow = "#a279c9", dark = "#a279c9",
    poison = "#8fbf5a", nature = "#8fbf5a",
    arcane = "#b98fe0",
}
local STEEL = "#dce1e6"

-- 3. FRAME -- class (vendor shelf) -> border colour.
local CLASS_COLOR = {
    fighter = "#c0562f",
    rogue = "#6f9a52",
    priest = "#d8c15f",
    mage = "#6f82d4",
    ranger = "#4f9a86",
    cleric = "#d8c15f",
}
local CLASS_DEFAULT = "#9aa0a8"

-- 4. BADGE -- type -> corner disc colour.
local TYPE_COLOR = {
    weapon = "#c9603a",
    ability = "#8a6fd0",
    armor = "#5f8fb0",
    utility = "#6fae72",
    material = "#b0894f",
    consumable = "#6fae72",
}
local TYPE_DEFAULT = "#888e96"

local function projectPath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

-- The item's element tint: first tag that names a colour, else steel.
local function tintFor(def)
    for _, tag in ipairs(def.tags or {}) do
        if ELEMENT_TINT[tag] then return ELEMENT_TINT[tag] end
    end
    return STEEL
end

-- The base silhouette slug: family first (a weapon), then type (everything else).
local function baseFor(def)
    local family = Item.archetype(def)
    if family and FAMILY_BASE[family] then return FAMILY_BASE[family] end
    return TYPE_BASE[def.type] or DEFAULT_BASE
end

-- Pull the recoloured foreground out of a vendored game-icons SVG: drop the outer <svg>, drop the
-- full-canvas background rect, recolour the #fff foreground to `tint`. Returns the inner markup (a
-- run of <path>s) ready to drop into a <g>, or nil + why. Same surgery as icon-build's transform,
-- minus the re-wrap -- the caller nests it instead of shipping it whole.
local function foreground(slug, tint)
    local raw = love.filesystem.read(ICON_ROOT .. "/" .. slug .. ".svg")
    if not raw then return nil, "no such icon: " .. slug end
    local inner = raw:match("<svg[^>]*>(.*)</svg>")
    if not inner then return nil, "unexpected SVG layout: " .. slug end
    inner = inner:gsub(BG_PATH:gsub("%p", "%%%0"), "", 1)
    -- Recolour explicit #fff fills; the enclosing <g fill> below catches any path that inherited.
    inner = inner:gsub('fill="#fff"', string.format('fill="%s"', tint))
    return inner
end

-- Compose the four layers into one 512x512 SVG. Everything here is a function of `def`.
local function compose(def)
    local tint = tintFor(def)
    local classColor = CLASS_COLOR[def.class] or CLASS_DEFAULT
    local typeColor = TYPE_COLOR[def.type] or TYPE_DEFAULT
    local tier = tonumber(def.repRank) or 0

    local inner, err = foreground(baseFor(def), tint)
    if not inner then return nil, err end

    local parts = { '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">' }

    -- Layer 1 backing: a dark plate so the icon reads on any panel.
    parts[#parts + 1] = '<rect x="24" y="24" width="464" height="464" rx="72" fill="#1b1f25"/>'

    -- Layer 1 base: the family/type silhouette, tinted, scaled to ~62% and nudged up to clear the pips.
    parts[#parts + 1] = string.format(
        '<g transform="translate(96 82) scale(0.625)" fill="%s">%s</g>', tint, inner)

    -- Layer 3 frame: the class border, thickening with tier.
    local frameW = 12 + tier * 4
    parts[#parts + 1] = string.format(
        '<rect x="30" y="30" width="452" height="452" rx="66" fill="none" stroke="%s" stroke-width="%d"/>',
        classColor, frameW)

    -- Layer 4 badge: the type disc, top-right.
    parts[#parts + 1] = string.format(
        '<circle cx="396" cy="116" r="72" fill="%s" stroke="#12151a" stroke-width="12"/>', typeColor)

    -- Layer 4 tier pips: `repRank` diamonds along the bottom, in the class colour.
    if tier > 0 then
        local cy, half, gap = 452, 13, 40
        local start = 256 - (tier - 1) * gap / 2
        for i = 0, tier - 1 do
            local cx = start + i * gap
            parts[#parts + 1] = string.format(
                '<polygon points="%d,%d %d,%d %d,%d %d,%d" fill="%s" stroke="#12151a" stroke-width="4"/>',
                cx, cy - half, cx + half, cy, cx, cy + half, cx - half, cy, classColor)
        end
    end

    parts[#parts + 1] = "</svg>"
    return table.concat(parts)
end

local function ensureDir(rel)
    local built
    for part in rel:gmatch("[^/]+") do
        built = built and (built .. "/" .. part) or part
        if not love.filesystem.getInfo(built) then
            os.execute(string.format('mkdir "%s" 2>nul', projectPath(built):gsub("/", "\\")))
        end
    end
end

local function writeFile(rel, text)
    local file, err = io.open(projectPath(rel), "w")
    if not file then return nil, tostring(err) end
    file:write(text)
    file:close()
    return true
end

-- Rasterize a staged SVG to PNG via resvg (the cmd.exe quoting dance is icon-build's).
local function rasterize(svgRel, pngRel)
    local cmd = string.format('"%s" "%s" "%s" --width %d --height %d',
        projectPath(RESVG):gsub("/", "\\"),
        projectPath(svgRel):gsub("/", "\\"),
        projectPath(pngRel):gsub("/", "\\"),
        RENDER_SIZE, RENDER_SIZE)
    local ok = os.execute('""' .. cmd:sub(2) .. '"')
    return ok == 0 or ok == true
end

-- The demo spread: one item per weapon family, then the first of each non-weapon type. Guarantees
-- every base slug and every type badge appears, and every id is real (drawn from the registry, not
-- hand-listed). Deterministic: ids sorted, first match wins.
local function demoSelection(defs)
    local ids = {}
    for id in pairs(defs) do ids[#ids + 1] = id end
    table.sort(ids)

    local picked, seenFamily, seenType = {}, {}, {}
    for _, id in ipairs(ids) do
        local def = defs[id]
        local family = Item.archetype(def)
        if family and not seenFamily[family] then
            seenFamily[family] = true
            picked[#picked + 1] = id
        elseif not family and def.type and not seenType[def.type] then
            seenType[def.type] = true
            picked[#picked + 1] = id
        end
    end
    return picked
end

function M.run(args)
    if not love.filesystem.getInfo(RESVG) then
        print("resvg not found at " .. RESVG)
        print("run:  powershell -ExecutionPolicy Bypass -File tools\\icons\\fetch.ps1")
        return
    end

    local all = false
    for _, a in ipairs(args or {}) do
        if a == "all" then all = true end
    end

    local defs = Registry.load("data/items", "data.items")

    local ids
    if all then
        ids = {}
        for id in pairs(defs) do ids[#ids + 1] = id end
        table.sort(ids)
    else
        ids = demoSelection(defs)
    end

    ensureDir(OUT_ROOT)
    ensureDir(OUT_ROOT .. "/staging")

    local rendered, failures = 0, {}
    for _, id in ipairs(ids) do
        local def = defs[id]
        local svg, err = compose(def)
        if not svg then
            failures[#failures + 1] = id .. " -- " .. tostring(err)
        else
            local stageRel = OUT_ROOT .. "/staging/" .. id .. ".svg"
            local pngRel = OUT_ROOT .. "/" .. id .. ".png"
            local wrote, werr = writeFile(stageRel, svg)
            if not wrote then
                failures[#failures + 1] = id .. " -- cannot stage: " .. tostring(werr)
            elseif rasterize(stageRel, pngRel) then
                rendered = rendered + 1
            else
                failures[#failures + 1] = id .. " -- resvg failed"
            end
        end
    end

    print("")
    print(string.format("  composed %d icon(s) into %s/", rendered, OUT_ROOT))
    print(string.format("  failed   %d", #failures))
    print("")
    for _, f in ipairs(failures) do print("  fail: " .. f) end
    if not all then
        print("")
        print("  (demo spread -- run `. icon-compose all` for every item)")
    end
end

return M
