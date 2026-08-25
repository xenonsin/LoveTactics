-- Regression guard for the art PIPELINE -- the plumbing around the composers, as distinct from the
-- guessing they do (tests/char_compose_spec.lua guards that).
--
-- Three contracts live here, each of which was a silent failure before it was written down:
--
--   1. A commissioned glyph WINS. tools/icon_source.lua searches art/bases/ before vendor/game-icons;
--      reverse that order and delivering art changes nothing on screen, with no error anywhere.
--   2. Drawn art overlays, base SVGs do not. art/bases/ is pipeline input consumed by the composers --
--      copying it into assets/ would ship the raw silhouettes as if they were game art.
--   3. The input fingerprint MOVES when an input moves. A staleness check that cannot tell two different
--      inputs apart reports FRESH forever, which is worse than not having one.
--
-- Deliberately NOT asserted: that any slug names a file on disk. The vendored set lives under vendor/
-- (gitignored, fetched by tools/icons/fetch.ps1) and art/bases/ starts empty, so a file-existence check
-- would go red on a fresh clone for reasons that have nothing to do with the pipeline. Same reasoning as
-- the note at the top of tests/char_compose_spec.lua.

local Source = require("tools.icon_source")
local Build = require("tools.art_build")
local Hash = require("tools.art_hash")
local Icon = require("tools.icon_compose")
local Char = require("tools.char_compose")

local cases = {}

local function case(name, fn)
    cases[#cases + 1] = { name = name, fn = fn }
end

-- 1. SEARCH ORDER -----------------------------------------------------------------------------------

case("icon_source searches art/bases before vendor/game-icons", function()
    assert(#Source.ROOTS == 2, "expected exactly two roots, got " .. #Source.ROOTS)
    assert(Source.ROOTS[1].path == Source.ART_ROOT,
        "commissioned art must be searched FIRST, or a delivered glyph changes nothing: got "
        .. tostring(Source.ROOTS[1].path))
    assert(Source.ROOTS[2].path == Source.VENDOR_ROOT,
        "the vendored set must be the FALLBACK: got " .. tostring(Source.ROOTS[2].path))
end)

case("a slug resolves to the same relative path in either root", function()
    -- The two sets share one address space on purpose: a swap needs no remapping table.
    assert(Source.pathFor("lorc/broadsword", Source.ART_ROOT) == "art/bases/lorc/broadsword.svg")
    assert(Source.pathFor("lorc/broadsword", Source.VENDOR_ROOT) == "vendor/game-icons/lorc/broadsword.svg")
end)

case("well-formed slugs are author/name, and malformed ones are rejected", function()
    assert(Source.wellFormed("lorc/broadsword"))
    assert(Source.wellFormed("caro-asercion/two-handed-sword"))
    assert(not Source.wellFormed("broadsword"), "a bare name names no author")
    assert(not Source.wellFormed("lorc/sub/dir"), "slugs are one level deep")
    assert(not Source.wellFormed(""), "empty is not a slug")
    assert(not Source.wellFormed(nil), "nil is not a slug")
end)

-- Every slug either composer can name must be a well-formed address, or it resolves nowhere in BOTH
-- roots and the asset silently draws nothing. This catches a typo in a hand-authored silhouette table
-- without needing the art on disk.
case("every item base slug is a well-formed address", function()
    local Registry = require("models.registry")
    local items = Registry.load("data/items", "data.items")
    local bad = {}
    for id, def in pairs(items) do
        local slug = Icon.baseFor(def)
        if not Source.wellFormed(slug) then
            bad[#bad + 1] = id .. " -> " .. tostring(slug)
        end
    end
    assert(#bad == 0, "malformed base slug(s): " .. table.concat(bad, ", ", 1, math.min(#bad, 8)))
end)

case("every character silhouette slug is a well-formed address", function()
    local Registry = require("models.registry")
    local chars = Registry.load("data/characters", "data.characters")
    local bad = {}
    for key, def in pairs(chars) do
        local slug = Char.slugFor(def, Char.tokenId(key))
        if not Source.wellFormed(slug) then
            bad[#bad + 1] = key .. " -> " .. tostring(slug)
        end
    end
    assert(#bad == 0, "malformed silhouette slug(s): " .. table.concat(bad, ", ", 1, math.min(#bad, 8)))
end)

-- 1b. THE VOCABULARY --------------------------------------------------------------------------------
--
-- The drawing set is a DECLARED list (tools/icon_compose.lua's BASE_VOCABULARY), not whatever 749
-- blueprints happen to resolve to. Before the gate the catalogue drew 262 silhouettes, 164 of them for
-- exactly one item, and every new ability added another without anybody deciding to. These three cases
-- are what keeps that from coming back.

case("every silhouette an item draws is in the vocabulary", function()
    local Registry = require("models.registry")
    local items = Registry.load("data/items", "data.items")
    local outside = {}
    for id, def in pairs(items) do
        local slug = Icon.baseFor(def)
        if not Icon.BASE_VOCABULARY[slug] then
            outside[#outside + 1] = id .. " -> " .. tostring(slug)
        end
    end
    assert(#outside == 0, "slug(s) outside the vocabulary: "
        .. table.concat(outside, ", ", 1, math.min(#outside, 8)))
end)

-- The other direction, and the one that actually costs money: an entry nobody draws is a drawing on the
-- commission that no item is waiting for. Structural fallbacks are exempt -- a type base for a type the
-- catalogue does not contain yet (no ability costs health) is a promise, not an order.
case("no vocabulary entry is idle except a structural fallback", function()
    local Registry = require("models.registry")
    local items = Registry.load("data/items", "data.items")
    local used = {}
    for _, def in pairs(items) do used[Icon.baseFor(def)] = true end

    local structural = {}
    for _, slug in pairs(Icon.FAMILY_BASE) do structural[slug] = true end
    for _, slug in pairs(Icon.TYPE_BASE) do structural[slug] = true end
    for _, slug in pairs(Icon.ABILITY_BASE) do structural[slug] = true end
    for _, slug in pairs(Icon.VERB_BASE) do structural[slug] = true end
    for _, slug in pairs(Icon.HOOK_BASE) do structural[slug] = true end
    for _, row in ipairs(Icon.FIELD_BASE) do structural[row[2]] = true end
    structural[Icon.DEFAULT_BASE] = true

    local idle = {}
    for slug in pairs(Icon.BASE_VOCABULARY) do
        if not used[slug] and not structural[slug] then idle[#idle + 1] = slug end
    end
    assert(#idle == 0, "vocabulary entr(ies) nothing draws: "
        .. table.concat(idle, ", ", 1, math.min(#idle, 8)))
end)

case("the bespoke list stays under its cap", function()
    assert(#Icon.BESPOKE <= Icon.BESPOKE_CAP,
        string.format("%d bespoke silhouettes, cap is %d", #Icon.BESPOKE, Icon.BESPOKE_CAP))
end)

-- 2. THE OVERLAY ------------------------------------------------------------------------------------

case("drawn art under art/ overlays onto the matching assets/ path", function()
    assert(Build.overlayTarget("art/items/kingsfall.png") == "assets/items/kingsfall.png")
    assert(Build.overlayTarget("art/portraits/knight.png") == "assets/portraits/knight.png")
    assert(Build.overlayTarget("art/chars/wolf.png") == "assets/chars/wolf.png")
    assert(Build.overlayTarget("art/overworld/forest/tileset.png") == "assets/overworld/forest/tileset.png",
        "nested directories must survive the mapping")
end)

case("art/bases is pipeline input and is never overlaid", function()
    assert(Build.overlayTarget("art/bases/lorc/broadsword.svg") == nil,
        "a base SVG is a composer INPUT -- copying it into assets/ would ship the raw silhouette")
    assert(Build.overlayTarget("art/bases") == nil)
end)

case("paths outside art/ overlay nothing", function()
    assert(Build.overlayTarget("assets/items/kingsfall.png") == nil)
    assert(Build.overlayTarget("data/items/weapon/kingsfall.lua") == nil)
    assert(Build.overlayTarget("artifacts/thing.png") == nil, "the prefix must be the art/ DIRECTORY")
end)

-- 3. THE FINGERPRINT --------------------------------------------------------------------------------

case("the input hash is deterministic", function()
    local a = Hash.ofString("lorc/broadsword\030fighter\0303")
    local b = Hash.ofString("lorc/broadsword\030fighter\0303")
    assert(a == b, "the same input must hash the same, or every build looks stale")
    assert(#a == 16, "expected a 16-char digest, got " .. #a .. " (" .. a .. ")")
end)

case("the input hash moves when any input moves", function()
    -- \030 is the field separator art_hash uses. Written with all three digits on purpose: "\30" followed
    -- by a digit reads as ONE escape (\304 = 304, out of range) and is a syntax error, not a separator.
    local base = Hash.ofString("item\030kingsfall\030lorc/crown-coin\030#dce1e6\0304")
    -- Each of these is a real way composed art goes stale: a re-tier, a base swap, a tint edit.
    local retiered = Hash.ofString("item\030kingsfall\030lorc/crown-coin\030#dce1e6\0305")
    local reBased = Hash.ofString("item\030kingsfall\030lorc/broadsword\030#dce1e6\0304")
    local reTinted = Hash.ofString("item\030kingsfall\030lorc/crown-coin\030#ef7d4a\0304")
    assert(base ~= retiered, "a repRank change must invalidate: it drives the frame and the tier pips")
    assert(base ~= reBased, "a base-slug change must invalidate")
    assert(base ~= reTinted, "a tint change must invalidate")
    assert(retiered ~= reBased and reBased ~= reTinted, "digests must not collide across these")
end)

case("the hash is sensitive to order, not just content", function()
    -- Canonical serialization sorts its keys; if the digest ignored order, an unsorted walk would go
    -- undetected and two runs over identical data could disagree.
    assert(Hash.ofString("ab") ~= Hash.ofString("ba"))
    assert(Hash.ofString("a\030b") ~= Hash.ofString("b\030a"))
end)

case("a one-character difference changes the digest", function()
    local seen = {}
    for i = 0, 63 do
        local h = Hash.ofString("slug-" .. i)
        assert(not seen[h], "digest collision between slug-" .. tostring(seen[h]) .. " and slug-" .. i)
        seen[h] = i
    end
end)

return cases
