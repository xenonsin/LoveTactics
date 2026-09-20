-- SWAILING: set fire to the ground, on purpose, and have nothing left of it.
--
-- The word is the real one -- the controlled burning of moor and gorse, done deliberately, by people
-- who mean to be rid of what is standing there. It is the Vengeful Spirit's only ability and the one
-- thing in this game that treats a hazard as a RESOURCE rather than as scenery.
--
-- WHAT IT DOES. Point it at a tile holding ground. That ground happens, at once, to everything in the
-- 3x3 around it -- and then the ground is gone.
--
-- THE BLAST IS WHATEVER IT ATE, and this is the whole design rather than a flourish. There is no table
-- of per-hazard blast effects here and there must never be one: the zone's own `onEnter` is run
-- against every body in the burst (fx.hazardTouch -> Hazard.applyTo), so fire burns them, briar charms
-- them, black ice cripples them, a Sanctuary heals them. One ability whose character is the floor
-- underneath it, with nothing authored twice and nothing to fall out of step the day a hazard is
-- tuned. It is also the fight's own thesis arriving in a single action: the ground turns on you, and
-- it does not care whose it was.
--
-- AND THE FLAT PART FOLLOWS THE GROUND'S ALLEGIANCE. A blast needs to cost something even when what it
-- consumed was harmless, or detonating a Wellspring is a free eight mana for everyone nearby and the
-- spirit has an ability that helps the party. So there is a flat component -- and it reads the zone's
-- `disposition` rather than assuming damage: friendly ground pays out as a heal, everything else as a
-- blow. That is what makes the carried version two items in one (utility_swailing_brand) instead of a
-- situational answer, and it costs one branch to say.
--
-- IT SPENDS THE TILE. fx.consumeHazard, the same call a Wellspring print makes on itself when the
-- first body drinks it dry -- so the zone unwinds by the ordinary rule, its onExpire fires, and
-- anything it was granting lapses when Hazard.reap next finds no ground under the bearer.
--
-- WHICH IS THE MAGAZINE, AND THE MAGAZINE IS THE FIGHT. The spirit's ammunition is the trail the STAG
-- laid while it was running away from the company -- every tile of New Growth, turned to Blight at the
-- threshold. Blight does not spread. Each cast spends one. So how much room the party gave it in the
-- first half is how many of these it has in the second, and that was decided before anybody knew it
-- mattered. A company that chased it across the whole board built a large magazine. One that cornered
-- it early and killed it in a pocket built a small one.
--
-- MANA, NOT STAMINA, AND MANA IS THE HARD CEILING. Nothing restores mana on its own in this game --
-- stamina regenerates every rebase and mana does not, which is the scarcity the Wellspring exists to
-- answer. So the pool is a COUNT: the spirit gets exactly floor(mana / cost) detonations in a fight
-- and no more, whatever the floor is covered in. That is the dial to turn if this ever measures
-- unwinnable -- the cost, or the pool -- and NEVER the tile count, which is the loop.
--
-- NOTHING ON CLEAN GROUND. An empty tile returns before any damage is dealt, which is also what keeps
-- the planner honest without a rule: AI.scoreCandidate dry-runs the effect, the dry run reads the real
-- board (fx.hazardsAt is the one of the three helpers that is not inert in a preview), and a tile with
-- no zone scores zero. It will not throw this at bare floor, and it will not throw it at New Growth
-- either -- that scores as a heal for the party, and the scorer refuses it.
--
-- A natural ability: no class, no price, no dropTier, noSteal. The carried version is a separate item
-- on the blueprint's `drops` list (docs/bestiary.md -- a boss's own kit is never handed over).
local Curve = require("models.curve")

-- The flat component, when the ground it ate was nobody's friend. Deliberately modest against the
-- spirit's own Deadfall (20-30): what makes a detonation worth a turn is the zone's effect landing on
-- three or four bodies at once, not this number.
-- The span is ten because a forge curve must climb a point per level or a level buys nothing
-- (models/curve.lua asserts it), not because 20 was reasoned to independently.
local BLAST = Curve.ramp(10, 20)

-- ...and when it was friendly ground, paid the other way. Under the blast figure on purpose: turning
-- somebody's sanctuary into one big heal should be worth doing and never worth farming, and the tile
-- is spent either way.
local MEND = 10

return {
    name = "Swailing",
    description = "Sets off the ground on a tile: whatever it does, it does to everything beside it, once.",
    flavor = "Burn the gorse before the gorse decides.",
    sprite = "assets/items/ability_swailing.png",
    type = "ability",
    class = "creature",
    tags = { "nature", "zone" },
    noSteal = true,
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- ground with a body standing on it is the point, not an obstacle
        range = 4,
        speed = 6,
        cost = { stat = "mana", amount = 12 },
        damage = BLAST,
        aoe = { radius = 1, shape = "square" }, -- 3x3: being NEAR bad ground is the danger
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local zones = fx.hazardsAt(fx.tx, fx.ty)
            local zone = zones and zones[1]
            -- Nothing to set off. Returns before anything is dealt, which is what scores this at zero
            -- on bare floor (see the header) -- so the refusal costs no rule.
            if not zone then return end

            -- Read BEFORE the burst: fx.hazardTouch can spend a one-shot zone through its own
            -- ctx.consume, and a def read afterwards would be read off ground that is already gone.
            local friendly = zone.def and zone.def.disposition == "friendly"

            for _, u in ipairs(fx.aoeUnits()) do
                -- The ground's own effect first, then the flat part. In that order because the zone is
                -- the ability and the number is the price of using it -- and because a hazard that
                -- kills outright should do so as itself rather than as a footnote to an explosion.
                fx.hazardTouch(zone, u)
                if friendly then fx.heal(u, MEND) else fx.damage(u) end
            end

            -- The tile, last. Everything above needed it standing.
            fx.consumeHazard(zone)
        end,
    },
}
