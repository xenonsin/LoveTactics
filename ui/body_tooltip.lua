-- THE BODY CARD: what a roster member IS, on hover, wherever the campaign asks you to choose between
-- them -- their pools, what an injury has taken off the top, and their flat stats with the gear folded
-- in.
--
-- IT DOES NOT LIST THE KIT. It used to, by name, and the list was the longest half of the card and the
-- half nobody read: the stat rows above it already carry what the gear is WORTH, in the figure the
-- decision is made on, and a body's blade is chosen in the Armory rather than at the Gate. Naming the
-- items again only asked the player to do the arithmetic the card had already done.
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
-- THE INJURY IS DRAWN AS THE TOP OF THE HEALTH BAR THAT WILL NOT FILL, the same picture the overworld
-- strip paints (ui/party_status.lua) -- because that is what the mechanic IS (models/injury.lua), and a
-- body who is at full health and still only three quarters of themselves is exactly the thing this
-- card exists to say before somebody sends them down a stair.
--
--   BodyTooltip.draw(player, char, mx, my, maxRight)   -- anchored near (mx, my), clamped on screen

local Character = require("models.character")
local Combat = require("models.combat")     -- for the injured ceiling, the way every other pool reads it
local Colors = require("ui.colors")
local Class = require("models.class")
local Theme = require("ui.theme")
local TileTooltip = require("ui.tile_tooltip")
local Injury = require("models.injury")

local BodyTooltip = {}

-- The card's width. Wider than a tile's box (210), because the widest rows here are a stat label
-- against a figure that carries its gear bonus with it -- "10 (+2)" -- and the injury statuses, which
-- are named in full rather than abbreviated.
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
    return Class.displayName(key) or titleCase(key)
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
    -- changes who you send.
    --
    -- THIS CARD IS WHERE THE INJURIES ARE NAMED, and that is a division of labour rather than an
    -- accident. The Ward's rows say what you can DO about a body (set a bone, rest it) and deliberately
    -- do not name the bone -- one press, the shallowest first, stated as a rule instead of asked as a
    -- question. So the reading happens here and on the deployment picker, which are the two surfaces a
    -- player is standing on when the question is "do I send this one".
    --
    -- ONE ROW PER KIND, carrying its name, how many of it, and what it is actually costing. A count
    -- alone answered "how bad" and nothing else, which was the whole of the meter while every injury was
    -- the same injury -- and is most of nothing now that a 3 can be a broken leg, a torn shoulder and a
    -- rattled head.
    local injuries = Injury.sorted(player, char.id)
    if #injuries > 0 then
        blocks[#blocks + 1] = { kind = "stat", label = "Injuries", value = tostring(#injuries),
            valueColor = Theme.accentWeapon }

        -- WHAT EACH ONE IS PAYING, asked of the model with the CHAR in hand rather than read off the
        -- blueprint: a stacked injury's badge carries the number left after the floor clamps it
        -- (models/injury.lua's Injury.STAT_FLOOR), so a card quoting the authored figure would promise a
        -- magnitude the bell will not stamp. Keyed by status id, which is what an effect names.
        local Status = require("models.status")
        local paying = {}
        for _, effect in ipairs(Injury.combatEffects(player, char.id, char)) do
            local parts = {}
            for stat, amount in pairs((effect.opts and effect.opts.statBonus) or {}) do
                if amount ~= 0 then parts[#parts + 1] = string.format("%s %+d", stat, amount) end
            end
            table.sort(parts)
            paying[effect.id] = table.concat(parts, ", ")
        end

        -- DEEPEST FIRST on the card, which is the reverse of the order a camp sets them in
        -- (Injury.sorted is shallowest-first, for the field dressing). A reader wants the worst thing
        -- about this body at the top; a field dressing wants the easiest thing to fix. Two questions,
        -- one ordering, read from both ends.
        local counted, order = {}, {}
        for i = #injuries, 1, -1 do
            local id = injuries[i].id
            if not counted[id] then
                counted[id] = 0
                order[#order + 1] = injuries[i]
            end
            counted[id] = counted[id] + 1
        end
        for _, entry in ipairs(order) do
            local def = entry.def
            local n = counted[entry.id]
            local name = (def.name or entry.id) .. (n > 1 and (" x" .. n) or "")
            -- Blood Loss stamps no status, so its cost is the pool it seals and there is nothing in
            -- `paying` to read. Quoted as a share rather than in hit points for the reason the model
            -- gives: the reservation is a fraction of a ceiling that moves with level and gear.
            local cost
            for _, effect in ipairs(def.effects or {}) do cost = cost or paying[effect.id] end
            if (not cost or cost == "") and def.reserve then
                local shares = {}
                for stat, share in pairs(def.reserve) do
                    shares[#shares + 1] = string.format("%s -%d%%", stat, math.floor(share * 100 * n + 0.5))
                end
                table.sort(shares)
                cost = table.concat(shares, ", ")
            end
            local badge = def.effects and def.effects[1] and Status.defs[def.effects[1].id]
            blocks[#blocks + 1] = { kind = "status",
                name = name .. ((cost and cost ~= "") and ("  " .. cost) or ""),
                color = (badge and badge.color) or Theme.accentWeapon }
        end
    end
    -- THERE IS NO "AT THE INN" ROW any more, and nothing replaces it. It answered the second of the two
    -- questions above -- whether this body was available to be picked at all -- which was real while a
    -- bed took somebody out of the company for a day an injury. Nobody is ever unavailable now
    -- (models/injury.lua): the surface sets every bone the moment the company reaches it, so the only
    -- question left is how broken they are underground and the rows above are the whole of it.

    for _, r in ipairs(RESOURCES) do
        local res = char.stats and char.stats[r.key]
        if type(res) == "table" and (res.max or 0) > 0 then
            -- The CEILING, asked of the one function that knows what an injury takes off a pool
            -- (Combat.unreservedMax reads `char.injuryShare`, stamped from the player's ledger by
            -- Injury.stamp). The bar then draws the difference as the locked tail at the far end.
            local ceiling = Combat.unreservedMax(char, r.key)
            local block = { kind = "bar", label = r.label, stat = r.key,
                cur = res.current or 0, max = ceiling, color = r.color }
            if ceiling < res.max then
                block.reserved = res.max - ceiling
                block.fullMax = res.max
                -- THE FIGURES ARE QUOTED AGAINST THE POOL'S TRUE SIZE, and the slice is named in
                -- INJURIES rather than in the health they took.
                --
                -- Both halves of that were wrong, and wrong in the same direction -- the card quoted
                -- a body against its own lowered ceiling, so an injured member topped up at the Ward
                -- read "56 / 56 (10 injured)": full health, apparently, carrying ten of something
                -- the row above had just called one. Against the true max the same body reads
                -- "56 / 66 (1 injury)" -- what they have, out of what they would have whole, and the
                -- one fact that explains the gap.
                --
                -- It is also what models/injury.lua says the mechanic IS ("the pool is the size it
                -- always was, and part of it is not available to you"), it is what the party sheet
                -- has always printed (ui/panels/party.lua reads Character.statTotal, which no injury
                -- touches), and the bar under the numbers is unchanged: the locked tail is still
                -- drawn from the health, because that is a width rather than a sentence.
                -- `injuries` is the body's LIST of kinds (Injury.sorted), so the count is its length.
                -- It names the number of injuries rather than the health they took, which is the half
                -- of this note that was wrong for longest.
                local n = #injuries
                if n > 0 then
                    block.max = res.max
                    block.reservedText = n .. (n == 1 and " injury" or " injuries")
                end
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
