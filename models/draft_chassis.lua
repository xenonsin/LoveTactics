-- Draft mode's CHASSIS strip: what a bought unit arrives carrying.
--
-- The campaign hands you a character whole -- Character.instantiate seeds the blueprint's authored 3x3
-- grid, which is four items for a Fighter, eight for a Mage, nine for a Barbarian. In the campaign that
-- is right: you meet the character, you learn the kit over a quest line. In DRAFT it is the mode's worst
-- problem. A 3g purchase drops up to nine full campaign items on the player at once -- each with a
-- weapon-family mechanic, tags, a per-level damage curve, cost, range, AoE footprint, wind-up,
-- bonus/resist, granted traits, an aura block, a wait-behaviour swap, and a grid POSITION that matters
-- because auras only reach neighbours -- and the player chose none of them. Meanwhile the gear row, the
-- part they actually decide, was the smaller share of their power.
--
-- So a drafted body is stripped to its CHASSIS: base stats, class identity, and the one or two items the
-- blueprint names as its signature (`signatureWeapon` / `signatureAbility`, see models/character.lua).
-- Everything else is discarded -- not stashed, because it was never the player's; they did not buy it.
-- The unit's remaining eight cells are filled by gear from the shop, one piece at a time, each one read
-- before it was bought. Round-one unknowns drop from roughly twenty-four to four.
--
-- The signatures are AUTHORED per character rather than derived here, because no rule over the kit picks
-- them reliably -- see the note in models/character.lua for the Ninja case that settles it.
--
-- Pure model (no love.graphics), so it loads under the headless tests.

local Character = require("models.character")
local Item = require("models.item")
local Trait = require("models.trait")

local DraftChassis = {}

-- The ids `char` keeps when stripped, as a set. Bound items are always in it: a bound relic is authored
-- identity nailed to its cell (Item.isBound), and models/draft_run.lua already refuses to strip one off
-- merge fodder -- honouring it here keeps the two agreeing.
--
-- A blueprint that names neither signature falls back to its `defaultAction` item, so an unauthored
-- character degrades to a thin chassis rather than an empty body or an unstripped one. Every id in the
-- draft pool is expected to name at least a weapon; tests/draft_chassis_spec.lua asserts it, so a gap is
-- a red test rather than a silent mulligan.
function DraftChassis.keptIds(char)
    local keep = {}
    if char.signatureWeapon then keep[char.signatureWeapon] = true end
    if char.signatureAbility then keep[char.signatureAbility] = true end
    if not next(keep) then
        local def = Character.defs[char.id]
        local fallback = def and def.defaultAction
        if fallback then keep[fallback] = true end
    end
    return keep
end

-- Strip `char`'s grid down to its chassis, in place, and return it.
--
-- Survivors are COMPACTED into cells 1..n rather than left where the blueprint placed them. The grid is
-- an adjacency surface (auras reach the eight neighbours, Character.adjacentIndices), so a chassis whose
-- two items sat in opposite corners would hand the player a build whose spacing they never chose and
-- cannot read. Packing them at the front makes the empty cells contiguous and the adjacency predictable.
--
-- Strips ONCE, and latches `char.chassis` to say so. The second call is a no-op, and that matters: by
-- then the grid holds gear the player bought, which is not a signature and not bound, and a naive
-- re-strip would throw all of it away. The flag makes the function safe to call from anywhere on the
-- draft side rather than a trap that only works on a body fresh out of Character.instantiate.
function DraftChassis.strip(char)
    if not (char and char.inventory) then return char end
    if char.chassis then return char end
    char.chassis = true
    local keep = DraftChassis.keptIds(char)

    local survivors = {}
    for cell = 1, Character.MAX_INVENTORY do
        local item = char.inventory[cell]
        if item and (keep[item.id] or Item.isBound(item)) then
            survivors[#survivors + 1] = item
        end
        char.inventory[cell] = nil
    end
    for i, item in ipairs(survivors) do
        char.inventory[i] = item
    end

    -- The pinned default action was a cell index into the layout we just rewrote; re-resolve it against
    -- the new packing, or clear it when the item it pointed at is no longer carried (Combat.defaultAction
    -- falls back to its auto-pick, which is what an unpinned character has always done).
    char.defaultActionSlot = nil
    local def = Character.defs[char.id]
    local pinned = def and def.defaultAction
    if pinned then
        for cell = 1, Character.MAX_INVENTORY do
            local item = char.inventory[cell]
            if item and item.id == pinned then
                char.defaultActionSlot = cell
                break
            end
        end
    end

    return char
end

-- Instantiate `id` already stripped -- what DraftShop.buyUnit and the house bot both want.
function DraftChassis.instantiate(id, progress)
    local char = Character.instantiate(id, progress)
    return DraftChassis.strip(char)
end

-- ---------------------------------------------------------------------------
-- Reading a chassis
-- ---------------------------------------------------------------------------

-- Two or three short words summarising what a unit DOES, for the shop card: its weapon family (the
-- mechanic the swing inherits -- axes cleave, daggers bleed) followed by the traits its kit grants. This
-- is the glance that lets a player compare the unit row without opening a single tooltip.
--
-- Takes the live character so it keeps working as gear is bought: a chassis that has picked up a bleed
-- charm starts reading as one. Returns a list of strings, possibly empty.
function DraftChassis.keywords(char, limit)
    limit = limit or 3
    local words, seen = {}, {}
    local function add(word)
        if not word or seen[word] then return end
        seen[word] = true
        words[#words + 1] = word
    end

    for _, item in ipairs(Character.eachItem(char)) do
        local family = Item.archetype(item)
        if family and family ~= "natural" then
            add((family:gsub("^%l", string.upper)))
            break
        end
    end

    for _, item in ipairs(Character.eachItem(char)) do
        for _, traitId in ipairs(item.traits or {}) do
            local def = Trait.defs and Trait.defs[traitId]
            add(def and def.name or nil)
            if #words >= limit then return words end
        end
    end

    return words
end

return DraftChassis
