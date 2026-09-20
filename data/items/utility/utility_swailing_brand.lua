-- THE SWAILING BRAND: the Vengeful Spirit's own trick, at a price.
--
-- THIS IS SECOND GROWTH, REBUILT. The first version of this piece let its bearer TAKE hostile ground
-- -- step into the fire and the fire becomes yours -- and the author's read of it was exactly right:
-- *"this is too strong you're essentially immune to hazards."* A passive that owns every zone it
-- touches scales with the enemy's own output and protects the bearer for free, forever.
--
-- What survived is the fantasy and not the terms. Enemy ground is still a resource; you now SPEND it
-- rather than own it, and the difference is the whole item:
--
--        Second Growth (cut)          The Brand
--        owns the zone permanently    spends it, once
--        passive, costs nothing       a turn, a cast, and the tile
--        you stand in fire, safely    you stand in fire, on fire
--        works on a clean board       does nothing on a clean board
--        scales with their casting    one zone per turn, and you spent yours
--
-- THE BLAST IS WHATEVER IT ATE, which is the ability's whole design and is argued in full at
-- data/items/ability/ability_swailing.lua -- the zone's own onEnter run against everything in the 3x3,
-- so there is no table of per-hazard effects and nothing to keep in step. Read that file first; this
-- one only differs in who is holding it.
--
-- AND IN A PLAYER'S HANDS IT IS TWO ITEMS, which is what makes it worth the top rung rather than being
-- a situational answer. The spirit only ever has bad ground to spend. A party has SANCTUARIES --
-- Renewing Ground, a Wellspring, hallowed ground a priest just consecrated -- and the flat component
-- follows the zone's `disposition`, so pointing the Brand at your own blessing pays it out as one
-- burst of healing across four bodies instead of three turns of standing still for it. Choosing which
-- ground to spend is the skill in it.
--
-- THE FRIENDLY HALF IS THE ROW MOST LIKELY TO NEED A NUMBER. It is strongest in a party that already
-- runs a priest and an alchemist -- the party that needs it least -- and it stacks with ground-laying
-- those bodies were doing anyway. It ships whole because the hostile-only version is a situational
-- answer rather than a tool, and this list already carries two of those; if it measures over, MEND is
-- the dial and the ability's own header says so.
--
-- FILED TO THE DRUID. The mage's shelf REMAKES ground -- "remakes the ground rather than hitting what
-- stands on it" is the Collegium's own sentence (utility_cinderstride_boots) -- and this is the
-- inverse move: it unmakes it. `class` is the vendor shelf and never an equip gate; anyone may carry
-- this, and nobody may buy it (`unstocked`).
--
-- THE CHASE, and priced as one. It is the deepest thing this fight hands over and it should be: an
-- item that does nothing at all on an empty board is one a company has to build a plan around before
-- it is worth a cell, which is late-game reasoning and never an opening piece.
local Curve = require("models.curve")

-- The span is ten because a forge curve must climb a point per level or a level buys nothing
-- (models/curve.lua asserts it). Matched to the spirit's own figures so the item a player carries and
-- the ability it was taken from cannot quietly disagree -- see ability_swailing.lua for the argument
-- behind both numbers.
local BLAST = Curve.ramp(10, 20)
local MEND = 10

return {
    name = "Swailing Brand",
    description = "Sets off the ground on a tile: whatever it does, it does to everything beside it, once.",
    flavor = "Burn the gorse before the gorse decides. Somebody in the wood knew the word for it.",
    sprite = "assets/items/utility_swailing_brand.png",
    type = "utility",
    tags = { "charm", "nature", "zone" },
    class = "druid",
    dropTier = 9, -- the chase: the deepest rung this fight reaches
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many the company
    -- carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- ground with a body standing on it is the point, not an obstacle
        range = 4,
        speed = 6,
        -- MANA, as the spirit pays it, and for the same reason one rung up: nothing in this game gives
        -- mana back on its own, so what a bearer can afford over a fight is a count rather than a rate.
        -- A caster who spends the Brand twice has spent a Fireball and a half.
        cost = { stat = "mana", amount = 12 },
        damage = BLAST,
        aoe = { radius = 1, shape = "square" },
        effect = function(fx)
            local zones = fx.hazardsAt(fx.tx, fx.ty)
            local zone = zones and zones[1]
            -- Nothing to set off. Returns before anything is dealt, so the hover preview promises
            -- nothing on clean ground and the cast is simply not worth making there.
            if not zone then return end

            -- Read BEFORE the burst: fx.hazardTouch can spend a one-shot zone through its own
            -- ctx.consume, and a def read afterwards would be read off ground that is already gone.
            local friendly = zone.def and zone.def.disposition == "friendly"

            for _, u in ipairs(fx.aoeUnits()) do
                -- The ground's own effect first, then the flat part -- the zone is the ability and the
                -- number is the price of using it (ability_swailing.lua argues the order).
                fx.hazardTouch(zone, u)
                if friendly then fx.heal(u, MEND) else fx.damage(u) end
            end

            -- The tile, last. Everything above needed it standing.
            fx.consumeHazard(zone)
        end,
    },
}
