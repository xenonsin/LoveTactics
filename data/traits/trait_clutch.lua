-- CLUTCH: a Dragon Egg's rule (data/characters/character_dragon_egg.lua). Round 2 (2026-09-25), on Keno's
-- round-1 note on the eggs: "Don't use gold, think of something else".
--
-- BROODING. An ally that ends its turn standing beside the egg broods it -- one stack of Brood
-- (status_brood). At three, the egg HATCHES: it leaves the board and a Wyrmling stands on its tile, at the
-- egg's own level. The egg takes no turns (it is `timeless`), which is why it hears every OTHER body's turn
-- end instead (Trait.onAnyTurnEnd).
--
-- THE CLOCK THE KOBOLDS HAVE TO KEEP RUNNING by standing still, which pulls the pack into one place: a
-- Broodkeeper stands AT the egg (`guardRadius = 1`), and every brooder is inside the Dragon's Eye. The
-- three answers are to smash the egg in one blow (a blow it survives rallies them -- trait_dragonkin), to
-- kill the brooders, or to shove them off it.
--
-- THE SAME RULE ON THE COMPANY'S EGG (ability_dragon_egg): any ally broods it, and what hatches fights for
-- the side that laid it. A company-side hatchling is a SUMMON of whoever laid the egg (`egg.layer`), so
-- it leaves with them and is never mistaken for somebody on the roster; an enemy-side one is a body in its
-- own right, and a kill-all waits for it.
local HATCH = 3
local WYRMLING = "character_wyrmling"

local function hatch(combat, egg)
    local Combat = require("models.combat")
    local Character = require("models.character")
    local Growth = require("models.growth")
    local x, y, side = egg.x, egg.y, egg.side
    local level = egg.hatchLevel or (egg.char and egg.char.level)
    egg.hatched = true -- read by trait_dragonkin: a hatching is the god arriving, not the god falling
    Combat.fell(combat, egg)
    local char = Character.instantiate(WYRMLING)
    if level and level > 1 then Growth.resolve(char, level) end
    local layer = egg.layer
    local opts = nil
    if side == "party" then opts = { summoned = true, summoner = (layer and layer.alive) and layer or nil } end
    local wyrm = Combat.addUnit(combat, char, side, x, y, opts)
    Combat.logEvent(combat, "action", "The egg splits, and a Wyrmling crawls out of it.", wyrm)
    return wyrm
end

-- AN EGG WITH NOBODY LEFT TO BROOD IT GOES COLD. The moment the last body on its side that takes turns has
-- fallen, the egg is dead too (onAnyDeath), so a kill-all ends with the line rather than on a walk across
-- the cave to smash a shell nobody is defending -- which is what the Clutch and the Choir measured at 31
-- and 49 unit-turns before this rule (tests/skirmish_spec.lua). Nobody is left to see it, so nobody is
-- Forsaken; `hatched` is not set, because it did not.
local function cold(combat, egg)
    for _, u in ipairs(combat.units or {}) do
        if u ~= egg and u.alive and u.side == egg.side and not u.timeless then return false end
    end
    return true
end

return {
    name = "Clutch",
    description = "An ally that ends its turn beside the egg broods it. Brooded three times, it hatches a Wyrmling.",
    onAnyDeath = function(ctx)
        local combat, egg = ctx.combat, ctx.unit
        if not (combat and egg and egg.alive) or not cold(combat, egg) then return end
        require("models.combat").fell(combat, egg)
        ctx.log("action", "With nobody left to brood it, the egg goes cold.", egg)
    end,
    onAnyTurnEnd = function(ctx)
        local combat, egg, actor = ctx.combat, ctx.unit, ctx.actor
        if not (combat and egg and egg.alive and actor and actor.alive) then return end
        if actor.side ~= egg.side or actor.timeless then return end
        local Combat = require("models.combat")
        if Combat.unitGap(egg, actor) > 1 then return end
        local Status = require("models.status")
        Status.apply(combat, egg, "status_brood", { magnitude = 1 })
        if Status.stacksOf(egg, "status_brood") >= HATCH then hatch(combat, egg) end
    end,
}
