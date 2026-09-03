-- The Demon Grunt's second note, and the one it pays for in mana. A grunt is a slow melee body with a
-- heavy swing (data/items/weapon/weapon_rending_claws.lua), which makes it the most kiteable thing the
-- horde fields: back away and it spends the rest of the fight walking. Brimstone is what it does about
-- that -- it spits a gout of its own hellfire at the ground you are backing across and sets it alight.
--
-- It answers kiting WITHOUT becoming a second ranged attacker, which is the distinction the demon
-- roster is built on: the imp's Cinder Spit is a dart thrown at a body, and this is thrown at GROUND.
-- The blow it lands on the way is small (it exists so the AI ever wants to throw it -- a cast whose
-- outcome is zero is dropped from the pool before it is ever scored, see AI.scoreCandidate, and a
-- pure field-layer scores nothing at all). What it is actually for is the fire it leaves: a 3x3 of
-- burning ground in the lane you meant to retreat down.
--
-- `minRange = 2` keeps the burst off its own feet -- a radius-1 square around a tile two away cannot
-- reach the caster's cell -- so it never sets itself alight to catch somebody.
--
-- The fire is the ordinary hazard every fire in this game leaves (data/hazards/hazard_fire.lua): it
-- burns whoever ENTERS it rather than whoever is standing in it, it creeps into forest, and water
-- douses it. Deliberately shorter-lived and cooler than a mage's Fireball -- a grunt's gout is not the
-- Arcanum's loudest argument, and a common enemy should not be able to close a lane for the rest of
-- the fight.
--
-- No `class` and no `price`: an enemy's kit, never a shelf item, exactly like the Champion's Roar and
-- Cleave. And 8 mana out of a 24-mana grunt is three castings for the whole battle, because mana does
-- not regenerate (Combat.regenerate) -- so a Drain Mana thrown at a grunt is a lane it does not get to
-- burn.
local Curve = require("models.curve")

return {
    name = "Brimstone",
    description = "Strikes a foe and leaves Fire in area.",
    flavor = "It cannot catch you. It can decide where you are willing to stand.",
    sprite = "assets/items/ability_fireball.png", -- placeholder until its own art exists
    type = "ability",
    class = "creature",
    tags = { "fire", "magical" }, -- `magical` routes the damage through magicDamage/magicDefense
    activeAbility = {
        target = "tile", -- ground, not a body: what it is aimed at is the retreat, not the retreater
        allowOccupied = true,
        range = 3,
        minRange = 2, -- far enough that the blast never covers the grunt's own cell
        requiresSight = true,
        speed = 5,
        cost = { stat = "mana", amount = 8 },
        damage = Curve.ramp(6, 16),
        aoe = { radius = 1, shape = "square" },
        -- Thrown at anybody at all, and left to the scorer from there: it sums the blast over
        -- everyone it catches and prices friendly fire above enemy damage, so a grunt finds the
        -- cluster and declines the one with an imp standing in it without a rule saying either.
        -- `normal` rather than `high`: the claws are still what a grunt would rather be doing.
        ai = { priority = "normal", act = "attack",
               when = { subject = "any_foe", test = "exists" } },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
            for _, c in ipairs(fx.aoeCells()) do
                fx.placeHazard(c.x, c.y, "hazard_fire", { amount = 3 + fx.level, duration = 8 + fx.level })
            end
        end,
    },
}
