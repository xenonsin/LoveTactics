-- Icon mapper: proposes a game-icons.net icon for every outstanding icon-shaped asset.
--
--     & "E:\LOVE\lovec.exe" . icon-map          # propose, write tools/icons/map.lua, report coverage
--     & "E:\LOVE\lovec.exe" . icon-map unmatched # ... and list what it could not match
--
-- Run tools/icons/fetch.ps1 first: this reads the vendored SVG sources.
--
-- The mapping is the ONLY hard part of the icon pipeline -- rendering is mechanical, but deciding
-- that `ability_bear_trap` should be drawn with `lorc/mantrap` is a judgement call 500 times over.
-- So this tool guesses, and a human corrects the guesses. It is explicitly not trying to be right
-- every time; it is trying to turn 500 blank decisions into a few dozen.
--
-- HAND EDITS ARE PRESERVED. Re-running never clobbers a choice a person made: an entry is rewritten
-- only when its `by` field is "auto". Change an icon and set `by = "hand"` and it is yours forever.
-- That is what makes this safe to re-run as new items are added -- see docs/art-assets.md.

local Report = require("tools.art_report")

local M = {}

local ICON_ROOT = "vendor/game-icons"
local MAP_PATH = "tools/icons/map.lua"

-- Buckets whose art is icon-shaped.
--
-- `chars` and `portraits` are absent because the board's character layer is painted, and an icon
-- standing among painted faces reads as unfinished art rather than as a style.
--
-- `hazards` is absent too, and permanently: a hazard is a patch of GROUND -- fire spreading over
-- tiles, rain falling on them -- and a centred line-art glyph reads as an object dropped on the board
-- instead of a condition covering it. Zones have no art of any kind now; the board draws every one of
-- them procedurally through shaders/field.lua. See docs/art-assets.md, "Hazards are not icons".
local ICON_BUCKETS = {
    items = true, traps = true, materials = true, props = true,
}

-- Item-id prefixes that say what KIND of thing it is, not what it depicts. Stripped before
-- matching so `ability_bear_trap` competes as "bear trap".
local PREFIXES = { "ability", "weapon", "armor", "trinket", "consumable", "relic", "sig" }

-- Words that carry no depiction and only dilute a score.
local STOPWORDS = {
    the = true, of = true, a = true, an = true, and_ = true, ["and"] = true, s = true,
}

-- This game's vocabulary translated into the icon set's vocabulary. game-icons.net has no "aegis",
-- "censer" or "blink" -- it has shields, incense and teleports. Without this layer those assets
-- score zero against 4180 icons and fall out as unmatched, which is what happened to a third of
-- the catalogue on the first pass.
--
-- Keyed on OUR word, valued with THEIRS. Add a row here rather than hand-mapping the same idea
-- repeatedly: `censer` alone covers nine items, `fists` seven, `aegis` five. A row here also
-- catches every future item that uses the word, which a hand-edit in map.lua cannot do.
local SYNONYMS = {
    -- sacred furniture
    censer = "incense", thurible = "incense",
    reliquary = "chalice", relic = "chalice",
    aegis = "shield", ward = "shield", warding = "shield",
    sigil = "rune", glyph = "rune",
    crozier = "staff", icon = "prayer", invocation = "prayer",
    blessing = "prayer", consecrate = "prayer", hallowed = "prayer", sacred = "prayer",
    smite = "holy", zealous = "holy", grace = "holy",

    -- vestments and armour, which the item names describe by tailoring rather than by shape
    habit = "robe", chasuble = "robe", stole = "robe", vesture = "robe", vestment = "robe",
    robes = "robe", silk = "robe", weave = "robe", cloth = "robe", wrap = "robe",
    mantle = "cloak", shroud = "cloak", pelt = "cloak",
    cuirass = "armor", carapace = "armor", harness = "armor", mail = "armor", plate = "armor",
    jerkin = "leather", leathers = "leather",
    striders = "boot", sandals = "sandal",
    buckler = "shield", bulwark = "shield",

    -- weapons
    maul = "hammer", kris = "dagger", slipknife = "dagger", knife = "dagger",
    longbow = "bow", hornbow = "bow", greataxe = "axe", greatsword = "sword",
    fists = "fist", unarmed = "fist", blow = "fist",
    shaft = "arrow", spitter = "crossbow",

    -- states, tempo and other abstractions
    blink = "teleport", haste = "sprint", quickened = "sprint", momentum = "sprint",
    cure = "healing", panacea = "healing", renewal = "healing", transfusion = "healing",
    revive = "healing", poultice = "healing", wellspring = "healing",
    fury = "enrage", berserkers = "enrage", reckless = "enrage",
    draught = "potion", brew = "potion", elixir = "potion", tonic = "potion",
    everflask = "potion", flask = "potion", mucus = "potion", ichor = "potion",
    envenom = "poison", envenomed = "poison", thirst = "poison",
    ledger = "notebook", ledgers = "notebook", tallies = "notebook", codex = "notebook",
    standard = "banner", muster = "banner", marching = "banner",
    decoy = "mirror", doppelganger = "mirror", understudy = "mirror",
    rime = "snowflake", rimebite = "snowflake", frost = "snowflake", hailfall = "snowflake",
    smokecloth = "smoke", stillshade = "smoke",
    lancet = "syringe", apothecarys = "syringe",
    knell = "skull", reapers = "skull", culling = "skull",
    updraft = "wind", gale = "wind", zephyr = "wind", windward = "wind",
    tide = "wave", tidesbreak = "wave", drowned = "wave",
}

-- Words this project writes closed up that the icon set writes open. Item names here are fond of
-- compounds -- `rimecloth`, `stormcloth`, `witchlight`, `powershot` -- and a compound is a single
-- token that matches nothing, so these scored zero against all 4180 icons purely by spelling.
-- Populated from the icon vocabulary at index time; see splitCompound.
local knownWords = {}

-- Split a closed compound into two known words: "rimecloth" -> "rime", "cloth". Returns nil when
-- the token is not a compound of two things we recognise, so ordinary long words are left alone.
local function splitCompound(word)
    if #word < 7 or knownWords[word] then return nil end
    for cut = 3, #word - 3 do
        local head, tail = word:sub(1, cut), word:sub(cut + 1)
        if (knownWords[head] or SYNONYMS[head]) and (knownWords[tail] or SYNONYMS[tail]) then
            return head, tail
        end
    end
    return nil
end

-- Rewrite a token list through SYNONYMS, splitting compounds first so both halves get translated.
local function translate(tokens)
    local out = {}
    for _, word in ipairs(tokens) do
        local head, tail = splitCompound(word)
        if head then
            out[#out + 1] = SYNONYMS[head] or head
            out[#out + 1] = SYNONYMS[tail] or tail
        else
            out[#out + 1] = SYNONYMS[word] or word
        end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- Tokenizing
-- ---------------------------------------------------------------------------

-- "items/ability_bear_trap.png" -> { "bear", "trap" }
local function assetTokens(path)
    local name = path:match("([^/]+)%.%a+$") or path
    for _, p in ipairs(PREFIXES) do
        name = name:gsub("^" .. p .. "_", "")
    end

    local out = {}
    for word in name:gmatch("[%a]+") do
        word = word:lower()
        if not STOPWORDS[word] then out[#out + 1] = word end
    end
    return translate(out)
end

-- "lorc/bear-head" -> { "bear", "head" }
local function slugTokens(slug)
    local name = slug:match("/([^/]+)$") or slug
    local out = {}
    for word in name:gmatch("[%a]+") do
        word = word:lower()
        if not STOPWORDS[word] then out[#out + 1] = word end
    end
    return out
end

-- ---------------------------------------------------------------------------
-- The icon index
-- ---------------------------------------------------------------------------

-- Author folders excluded from matching. `badges` is not a style clash waiting to happen, it IS
-- one: those 59 are 256px medallions built from a filled circle and a ring stroke, where the other
-- 4180 are line icons on a 512px canvas. One badge among a panel of icons reads as a mistake.
local SKIP_AUTHORS = { badges = true }

-- game-icons.net is a general-purpose set: it has bowling, lab coats and the Arc de Triomphe
-- alongside the swords. Substring matching finds those cheerfully -- "Power Strike" landed on
-- `bowling-strike`, "Boots of Speed" on `speed-boat`, "Confessor's Needle" on `space-needle` --
-- and one modern object in a fantasy inventory reads as a bug, not a quirk.
--
-- Any icon carrying one of these words is dropped from the index entirely, so it cannot be matched
-- by accident. This is a register filter, not a taste filter: the question for adding a word is
-- "could this object exist in this game's world?", not "do I like this icon?".
local BLOCKED_WORDS = {
    -- sport
    bowling = true, baseball = true, basketball = true, football = true, soccer = true,
    tennis = true, golf = true, hockey = true, curling = true, surfer = true, juggling = true,
    boxing = true, rugby = true, cricket = true,
    -- modern tech, office and vehicles
    radio = true, cpu = true, computer = true, phone = true, camera = true, laptop = true,
    folder = true, printer = true, battery = true, turbine = true, boat = true, ship = true,
    car = true, truck = true, bus = true, tractor = true, bicycle = true, motorcycle = true,
    plane = true, balloon = true, rocket = true, satellite = true, robot = true, cyber = true,
    laser = true, nuclear = true, microscope = true, telescope = true, ceiling = true,
    lab = true, syringe = false, -- a lancet is period-plausible; a lab coat is not
    -- firearms: this game's ranged weapons are bows
    gun = true, gunshot = true, shotgun = true, rifle = true, pistol = true, bullet = true,
    slingshot = true, revolver = true, missile = true, grenade = true,
    -- food
    pepper = true, lemon = true, cheese = true, kebab = true, pizza = true, burger = true,
    sandwich = true, cake = true, donut = true, sushi = true, taco = true, popcorn = true,
    -- real-world places, brands and modern medicine
    triomphe = true, asclepius = true, space = true, gps = true, wifi = true,
    -- misc modern idiom that reads as a joke in a fantasy panel
    ["3d"] = true, mug = true, brainstorm = true, hive = true, drum = true, static = true,
    speedometer = true, cooking = true, cannon = true, drill = true,
    -- Added by the multiclass pass, all four caught matching the WRONG SENSE of a word the game
    -- genuinely uses. Same test as the rest of this table -- could this object exist in this world?
    --   `oil-rig`             took Salvage Rig; there is no drilling here
    --   `finish-line`         took BOTH Ley Line and Sapper's Line, on a word this game means
    --                         geometrically ("a line of charges") and never as a race
    --   `relationship-bounds` took Beat the Bounds -- a parish boundary, not a modern therapy chart
    --   `first-aid-kit`       took the Culler's Kit, which is for butchering rather than healing
    oil = true, finish = true, relationship = true, aid = true,
}

-- True when an icon belongs to a register this game cannot use.
--
-- Checks the raw hyphen-separated segments rather than the matcher's tokens, because tokens keep
-- letters only: `3d-hammer` tokenizes to { "d", "hammer" }, so a `3d` entry above would never fire
-- and every maul in the game kept landing on a 3D-modelling icon.
local function blocked(name)
    for segment in name:gmatch("[^%-]+") do
        if BLOCKED_WORDS[segment:lower()] then return true end
    end
    return false
end

-- Every vendored icon as { slug = "lorc/bolas", author = "lorc", tokens = {...}, joined = "bolas" }.
local function buildIndex()
    local index = {}
    local ok, authors = pcall(love.filesystem.getDirectoryItems, ICON_ROOT)
    if not ok or not authors then return nil end

    for _, author in ipairs(authors) do
        local dir = ICON_ROOT .. "/" .. author
        local info = love.filesystem.getInfo(dir)
        if info and info.type == "directory" and not SKIP_AUTHORS[author] then
            for _, file in ipairs(love.filesystem.getDirectoryItems(dir)) do
                local name = file:match("^(.+)%.svg$")
                if name then
                    local slug = author .. "/" .. name
                    local tokens = slugTokens(slug)
                    if not blocked(name) then
                        -- Every word the icon set uses becomes a word we can split a compound on.
                        for _, word in ipairs(tokens) do
                            if #word >= 3 then knownWords[word] = true end
                        end
                        index[#index + 1] = {
                            slug = slug,
                            author = author,
                            tokens = tokens,
                            joined = table.concat(tokens, ""),
                        }
                    end
                end
            end
        end
    end
    return index
end

-- ---------------------------------------------------------------------------
-- Scoring
-- ---------------------------------------------------------------------------

-- How well `icon` matches a list of words. Higher is better; 0 means nothing in common.
--
--   * every word matched exactly by an icon word is worth a lot
--   * a word matched only as a substring (trap <- mantrap) is worth about half
--   * an icon carrying words the asset never mentioned is penalised, so a precise icon beats a
--     busier one that happens to contain the right word
--
-- `weightHead` weights the LAST word double, for name words: English compounds put the thing being
-- depicted last, so a "bellfounder's HAMMER" is a hammer and a "falconer's GLOVE" is a glove.
-- Weighting the head noun stops a vivid modifier from dragging the match onto the wrong object.
local function scoreWords(words, icon, weightHead)
    if #words == 0 then return 0 end

    local matched, weightTotal, anything = 0, 0, false
    for i, word in ipairs(words) do
        local weight = (weightHead and i == #words) and 2 or 1
        weightTotal = weightTotal + weight

        local exact = false
        for _, iword in ipairs(icon.tokens) do
            if word == iword then exact = true; break end
        end

        if exact then
            matched = matched + weight
            anything = true
        elseif #word >= 4 and icon.joined:find(word, 1, true) then
            matched = matched + weight * 0.5
            anything = true
        end
    end

    if not anything then return 0 end

    local coverage = matched / weightTotal             -- how much of the asset the icon accounts for
    local precision = matched / math.max(#icon.tokens, 1) -- how little of the icon is unaccounted for

    -- Coverage matters more than precision: depicting the whole idea beats depicting it tersely.
    return coverage * 0.7 + precision * 0.3
end

-- The asset's name and its archetype family are scored SEPARATELY and combined by taking the better
-- of the two, because they answer different questions and a blank answer to one should never veto
-- the other. Folding the family into the same denominator was worse than useless: an item called
-- "Sworn Lance" matches no icon by name, so mixing in its `spear` tag only diluted a zero, and the
-- pikes and lances lost matches they should have won outright.
local function score(tokens, joined, icon, tags)
    local byName = scoreWords(tokens, icon, true)

    -- Slightly discounted: the family says what an item IS, but many items share a family, so a name
    -- that names its own picture should still win.
    local byTag = scoreWords(tags or {}, icon, false) * 0.9

    local s = math.max(byName, byTag)
    if byName > 0 and byTag > 0 then s = s + 0.1 end -- name and family agree: more confident

    -- The whole name, identical: that is not a guess, it is the icon.
    if joined == icon.joined then s = s + 1 end
    return s
end

-- Item blueprints keyed by the sprite they ask for. An item's NAME says what it means -- "Kingsfall",
-- "Wolf's Portion" -- while its archetype tag says what it IS. Matching on the name alone throws that
-- away and leaves a greatsword looking for an icon called "kingsfall". Note the key is the def's
-- `sprite` field, not its filename: data/items/weapon/weapon_iron_sword.lua draws items/sword.png.
local function spriteArchetypes()
    local ok, Item = pcall(require, "models.item")
    if not ok then return {} end

    local out = {}
    for _, def in pairs(Item.defs or {}) do
        if type(def) == "table" and def.sprite and def.tags then
            local words = {}
            for _, tag in ipairs(def.tags) do
                -- Only the family tags depict anything. `physical`, `melee` and `magical` are
                -- mechanics -- they would add noise to every score without ever naming a picture.
                if Item.ARCHETYPES[tag] then words[#words + 1] = tag end
            end
            if #words > 0 then
                out[def.sprite:gsub("^assets/", "")] = translate(words)
            end
        end
    end
    return out
end

local function bestMatch(path, index, archetypes)
    local tokens = assetTokens(path)
    local joined = table.concat(tokens, "")

    -- The archetype informs but must not outvote the name: two different maces should not both land
    -- on the same mace icon when their names point somewhere more specific.
    local tags = archetypes and archetypes[path:gsub("^assets/", "")] or nil

    local best, bestScore = nil, 0
    for _, icon in ipairs(index) do
        local s = score(tokens, joined, icon, tags)
        if s > bestScore then best, bestScore = icon, s end
    end
    return best, bestScore
end

-- ---------------------------------------------------------------------------
-- The map file
-- ---------------------------------------------------------------------------

local function loadExisting()
    local ok, existing = pcall(function() return require("tools.icons.map") end)
    if ok and type(existing) == "table" then return existing end
    return {}
end

-- Hand-authored decisions live in their own file rather than as edits to the generated map, so a
-- person's choices are reviewable in one diff and can never be lost to a regeneration bug.
local function loadOverrides()
    local ok, over = pcall(function() return require("tools.icons.overrides") end)
    if ok and type(over) == "table" then return over end
    return {}
end

-- An override may name an icon either fully ("lorc/incense") or by name alone ("incense"), because
-- which artist drew a given icon is not something anyone writing these should have to look up.
-- Returns the full slug, or nil if no icon by that name exists.
local function resolveSlug(name, index)
    if name:find("/") then
        for _, icon in ipairs(index) do
            if icon.slug == name then return name end
        end
        return nil
    end

    for _, icon in ipairs(index) do
        if icon.slug:match("/(.+)$") == name then return icon.slug end
    end
    return nil
end

local function projectPath(rel)
    return love.filesystem.getSource() .. "/" .. rel
end

-- Sorted keys, so the generated file has a stable diff.
local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function writeMap(map)
    local lines = {
        "-- GENERATED by `& \"E:\\LOVE\\lovec.exe\" . icon-map`, then hand-corrected.",
        "--",
        "-- Maps an asset path (relative to assets/) to the game-icons.net icon that draws it.",
        "--",
        "--   by = \"auto\"  a guess. Re-running icon-map will overwrite it.",
        "--   by = \"hand\"  a human decision. Re-running icon-map will NEVER touch it.",
        "--   icon = false  deliberately has no icon yet; left for an artist.",
        "--",
        "-- Correct a bad guess by editing `icon` and setting `by = \"hand\"`.",
        "-- `. icon-build` renders every entry here into assets/.",
        "return {",
    }

    for _, key in ipairs(sortedKeys(map)) do
        local e = map[key]
        local icon = e.icon and string.format("%q", e.icon) or "false"
        lines[#lines + 1] = string.format("    [%q] = { icon = %s, by = %q },", key, icon, e.by)
    end

    lines[#lines + 1] = "}"
    lines[#lines + 1] = ""

    local text = table.concat(lines, "\n")

    -- Never write a file that would not load: a serializer slip must not break the next run.
    local chunk, err = loadstring(text)
    if not chunk then error("refusing to write a malformed map.lua: " .. tostring(err)) end

    local file, ferr = io.open(projectPath(MAP_PATH), "w")
    if not file then error("cannot write " .. MAP_PATH .. ": " .. tostring(ferr)) end
    file:write(text)
    file:close()
end

-- ---------------------------------------------------------------------------

function M.run(args)
    local listUnmatched = false
    for _, a in ipairs(args or {}) do
        if a == "unmatched" then listUnmatched = true end
    end

    local index = buildIndex()
    if not index or #index == 0 then
        print("no icons found under " .. ICON_ROOT)
        print("run:  powershell -ExecutionPolicy Bypass -File tools\\icons\\fetch.ps1")
        return
    end
    print(string.format("indexed %d icons from %s", #index, ICON_ROOT))

    local archetypes = spriteArchetypes()
    local existing = loadExisting()
    local overrides = loadOverrides()
    local map = {}
    local kept, guessed, unmatched, badOverrides = 0, 0, {}, {}

    for bucket, contents in pairs(Report.scan()) do
        if ICON_BUCKETS[bucket] then
            -- Everything the bucket names, present or not: a rendered icon is still mapped, so the
            -- map stays a complete record rather than emptying out as art lands.
            local paths = {}
            for _, p in ipairs(contents.present) do paths[#paths + 1] = p end
            for _, p in ipairs(contents.missing) do paths[#paths + 1] = p end

            for _, path in ipairs(paths) do
                local key = path:gsub("^assets/", "")
                local prior = existing[key]
                local override = overrides[key]

                if override then
                    local slug = resolveSlug(override, index)
                    if slug then
                        map[key] = { icon = slug, by = "hand" }
                        kept = kept + 1
                    else
                        -- Naming an icon that does not exist is a typo, not a decision to skip.
                        badOverrides[#badOverrides + 1] = key .. " -> " .. tostring(override)
                        map[key] = { icon = false, by = "auto" }
                        unmatched[#unmatched + 1] = key
                    end
                elseif prior and prior.by == "hand" then
                    map[key] = prior -- a person decided this; leave it alone
                    kept = kept + 1
                else
                    local icon, s = bestMatch(path, index, archetypes)
                    if icon and s >= 0.5 then
                        map[key] = { icon = icon.slug, by = "auto" }
                        guessed = guessed + 1
                    else
                        map[key] = { icon = false, by = "auto" }
                        unmatched[#unmatched + 1] = key
                    end
                end
            end
        end
    end

    writeMap(map)

    local total = kept + guessed + #unmatched
    print("")
    print(string.format("  %-22s %d", "hand-mapped (kept)", kept))
    print(string.format("  %-22s %d", "auto-matched", guessed))
    print(string.format("  %-22s %d", "no match", #unmatched))
    print(string.format("  %-22s %d", "total", total))
    print("")
    print(string.format("wrote %s -- correct any bad guess in tools/icons/overrides.lua", MAP_PATH))

    if #badOverrides > 0 then
        print("")
        print("overrides naming an icon that does not exist:")
        for _, b in ipairs(badOverrides) do print("  " .. b) end
    end

    if listUnmatched and #unmatched > 0 then
        table.sort(unmatched)
        print("")
        print("no match:")
        for _, key in ipairs(unmatched) do print("  " .. key) end
    end
end

return M
