-- THE BODY CARD: what a roster member IS, on hover, wherever the campaign asks you to choose between
-- them -- their pools, what a wound has taken off the top, their flat stats with the gear folded in,
-- and the kit they are carrying.
--
-- WRITTEN FOR THE GATE, where the question is "who goes down" and the answer is four bodies out of a
-- company (ui/expedition_picker.lua). That screen drew each member as a tile with a sprite on it, which
-- says who they are and nothing about what they are worth -- so picking an expedition meant remembering
-- eight loadouts, or opening the Armory and coming back. The card is that memory, under the cursor.
--
-- IT RENDERS THROUGH ui/tile_tooltip.lua rather than beside it. That module owns the game's readout
-- grammar -- a title, label/value rows with dotted leaders, pool bars that can draw a reserved tail,
-- headed sections -- along with the measuring and the on-screen clamp, and none of that is about
-- ground. So this assembles a block list and hands it over (`info.blocks`); what the player reads at
-- the Gate is the same box, in the same hand, as what they read over a tile in a fight.
--
-- THE WOUND IS DRAWN AS THE TOP OF THE HEALTH BAR THAT WILL NOT FILL, the same picture the overworld
-- strip paints (ui/party_status.lua) -- because that is what the mechanic IS (models/wound.lua), and a
-- body who is at full health and still only three quarters of themselves is exactly the thing this
-- card exists to say before somebody sends them down a stair.
--
--   BodyTooltip.draw(player, char, mx, my, maxRight)   -- anchored near (mx, my), clamped on screen

local Character = require("models.character")
local Combat = require("models.combat")     -- for the wounded ceiling, the way every other pool reads it
local Colors = require("ui.colors")
local Discipline = require("models.discipline")
local Gate = require("models.gate")         -- a body in a bed is not a body you can send
local Item = require("models.item")
local Theme = require("ui.theme")
local TileTooltip = require("ui.tile_tooltip")
local Wound = require("models.wound")

local BodyTooltip = {}

-- The card's width. Wider than a tile's box (210), because these rows carry item NAMES against a value
-- column -- "Rain of Arrows" and "Ability" in the same line -- where a tile's rows carry a word.
BodyTooltip.WIDTH = 250

-- Pools, in the order the party sheet stacks them. Health takes the party blue it wears on every board
-- token and every strip, so the same body's bar is the same colour wherever it is drawn.
local RESOURCES = {
    { key = "health",  label = "HP", color = Colors.PARTY },
    { key = "mana",    label = "MP", color = Colors.MANA },
    { key = "stamina", label = "SP", color = Colors.STAMINA },
}

-- The flat stats, under the labels the LOADOUT panel uses (ui/panels/party.lua's STAT_ROWS) rather
-- than the battle tooltip's. This is a campaign screen: the figure a player compares this against is
-- the one on the character sheet they equipped from an hour ago.
local STAT_ROWS = {
    { key = "damage",       label = "Attack" },
    { key = "magicDamage",  label = "Magic" },
    { key = "defense",      label = "Defense" },
    { key = "magicDefense", label = "M.Def" },
    { key = "movement",     label = "Move" },
    { key = "speed",        label = "Speed" },
}

local function titleCase(s)
    return (tostring(s):gsub("_", " "):gsub("^%l", string.upper))
end

-- What a body is, in one word: the discipline it has become, else the class it grows as. The same
-- precedence and the same fallback the loadout panel's ledger keeps, so a renamed-away id reads as a
-- slug in both places instead of vanishing from one.
local function classLabel(char)
    local key = char.discipline or char.class
    if not key then return nil end
    return Discipline.displayName(key) or titleCase(key)
end

-- What KIND of thing an item is, for the value column. A weapon answers with its FAMILY -- an axe
-- cleaves and a dagger bleeds (docs/weapons.md), so "Axe" is the useful word and "Weapon" is not --
-- and everything else answers with its type.
local function itemKind(item)
    local family = Item.archetype(item)
    if family then return titleCase(family) end
    return titleCase(item.type or "item")
end

-- The card's contents, as tile_tooltip blocks. Split out from the draw so a spec can read what the
-- card says without a window.
function BodyTooltip.blocks(player, char)
    if not char then return nil end
    local blocks = {}

    blocks[#blocks + 1] = { kind = "title", text = char.name or "Somebody", color = Colors.PARTY }
    local class = classLabel(char)
    if class then blocks[#blocks + 1] = { kind = "stat", label = "Class", value = class } end

    -- WHAT IS WRONG WITH THEM, ahead of everything they can do -- it is the one fact on this card that
    -- changes who you send, and the two rows are different questions: how broken, and whether they are
    -- even available to pick.
    local wounds = Wound.count(player, char.id)
    if wounds > 0 then
        blocks[#blocks + 1] = { kind = "stat", label = "Wounds", value = tostring(wounds),
            valueColor = Theme.accentWeapon }
        -- ...AND WHAT THEY WILL FIGHT UNDER. A wound is a reserved pool at one, and a debuff on top of
        -- it at two and again at three (models/wound.lua) -- none of which is in the stat rows below,
        -- because those are the campaign figures and this is a status the battle stamps at the bell.
        -- Read off Wound.combatEffects rather than restated here, so the card cannot promise a rung
        -- the ladder no longer has.
        local Status = require("models.status")
        for _, effect in ipairs(Wound.combatEffects(player, char.id)) do
            local def = Status.defs[effect.id] or {}
            blocks[#blocks + 1] = { kind = "status", name = def.name or effect.id,
                color = def.color or Theme.accentWeapon }
        end
    end
    if Gate.isLodged(player, char.id) then
        blocks[#blocks + 1] = { kind = "stat", label = "At the Inn", value = "mending",
            valueColor = Theme.accentWeapon }
    end

    for _, r in ipairs(RESOURCES) do
        local res = char.stats and char.stats[r.key]
        if type(res) == "table" and (res.max or 0) > 0 then
            -- The CEILING, asked of the one function that knows what a wound takes off a pool
            -- (Combat.unreservedMax reads `char.woundShare`, stamped from the player's ledger by
            -- Wound.stamp). The bar then draws the difference as the locked tail at the far end.
            local ceiling = Combat.unreservedMax(char, r.key)
            local block = { kind = "bar", label = r.label, stat = r.key,
                cur = res.current or 0, max = ceiling, color = r.color }
            if ceiling < res.max then
                block.reserved = res.max - ceiling
                block.fullMax = res.max
                -- Named, because the slice means something different here than it does in a fight: in
                -- a battle a locked tail is a summon being sustained and reads "res.", and this one is
                -- a bone that has not been set.
                block.reservedLabel = "wounded"
            end
            blocks[#blocks + 1] = block
        end
    end

    blocks[#blocks + 1] = { kind = "sep" }
    for _, row in ipairs(STAT_ROWS) do
        local base = char.stats and char.stats[row.key]
        if type(base) == "number" then
            -- The EFFECTIVE figure, gear folded in (Character.statTotal), with what the gear is worth
            -- named beside it -- the same reading the sheet prints, and the reason a body with a poor
            -- base and a good kit does not read as the weaker pick.
            local total = Character.statTotal(char, row.key)
            local value = tostring(total)
            local bonus = total - base
            if bonus ~= 0 then value = value .. " (" .. (bonus > 0 and "+" or "") .. bonus .. ")" end
            blocks[#blocks + 1] = { kind = "stat", label = row.label, value = value }
        end
    end

    -- THE KIT, by name. Not the 3x3 grid: adjacency is what the grid is for and the Armory is where it
    -- is arranged -- what this card owes the question at the Gate is which blade and which spells walk
    -- down the stair, which is a list.
    blocks[#blocks + 1] = { kind = "sep" }
    blocks[#blocks + 1] = { kind = "head", text = "Carrying", color = Theme.accentAmber }
    local items = Character.eachItem(char)
    if #items == 0 then
        blocks[#blocks + 1] = { kind = "desc", text = "Nothing at all." }
    end
    for _, item in ipairs(items) do
        local name = item.name or item.id or "?"
        if (item.quantity or 1) > 1 then name = name .. "  x" .. item.quantity end
        blocks[#blocks + 1] = { kind = "stat", label = name, value = itemKind(item) }
    end

    return blocks
end

-- Draw the card for `char` near (mx, my). `maxRight` caps its right edge (defaults to the screen).
-- A no-op for no body, so a caller can hand in whatever is under the cursor.
function BodyTooltip.draw(player, char, mx, my, maxRight)
    local blocks = BodyTooltip.blocks(player, char)
    if not blocks then return end
    return TileTooltip.draw({ blocks = blocks }, mx, my, maxRight, { width = BodyTooltip.WIDTH })
end

return BodyTooltip
