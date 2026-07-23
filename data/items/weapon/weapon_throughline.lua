-- The Throughline: a needle-thin blade that does not stop where the body does. Every thrust carries
-- through into the tile directly behind whatever it hits.
--
-- A DAGGER THAT REFUSES TO BE SINGLE-TARGET, which is the one thing daggers in this game cannot
-- otherwise be. The rogue's whole shelf is conditional multipliers on one victim -- guile, execution,
-- bleed, debuff-count scaling -- and all of it is worth nothing when the fight is three bodies in a
-- corridor. This is the rogue's answer to a line, and it is deliberately a poor one: a knife's damage
-- twice is still a knife's damage.
--
-- What makes it worth carrying is not the second hit's size but the fact that it exists at all, because
-- every conditional the rogue owns reads a HIT rather than a kill. A Throughline thrust puts bleed on
-- two bodies, springs Rimebite on two bodies, and feeds the debuff-count scaling on the next swing
-- twice. It is a multiplier on the rest of the loadout rather than on itself.
--
-- Still a `dagger`, so it inherits the family's bleed contract (docs/weapons.md) and the whole rogue
-- catalog can read it. The spill is the deviation, and it is the only one.
--
-- ADJACENCY: it scales off `dagger` neighbours -- the second hit lands harder for each other knife in
-- the grid. That is the Undercroft's actual doctrine (nobody carries one blade) rendered as a number,
-- and it makes a two-dagger loadout meaningfully different from a dagger-and-charm one, which the
-- shelf could not previously express.
return {
    name = "The Throughline",
    description = "A thrust that carries into the tile behind the target, harder per adjacent dagger.",
    flavor = "The Undercroft teaches the angle, not the blade. The angle is the part that costs money.",
    sprite = "assets/items/weapon_throughline.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical" },
    class = "rogue",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- the family contract: a dagger is quick (docs/weapons.md, tests/weapon_spec.lua)
        cost = { stat = "stamina", amount = 5 },
        -- Under a plain Iron Dagger's, deliberately: what this blade sells is the second body, and a
        -- knife that spilled AND hit hardest would simply retire the rest of the rack.
        damage = { 7, 8, 8, 9, 10, 11, 11, 12, 13, 14, 15 },
        -- What the spill scales off, declared so the loadout draws its connector lines to exactly the
        -- knives it will actually count (Combat.adjacencyLinks reads this).
        adjacencyScaling = { tag = "dagger" },
        -- The family contract: a dagger opens the wound it is named for.
        inflicts = { id = "status_bleed" },
        effect = function(fx)
            local hit = fx.damage(fx.target)
            if hit <= 0 then return end
            -- The tile DIRECTLY BEHIND, along the caster->target line: the thrust does not choose a
            -- second victim, the geometry does. A blade that picked its own second target would be a
            -- cleave, and cleaves belong to the axe (docs/weapons.md).
            local dx = fx.target.x - fx.user.x
            local dy = fx.target.y - fx.user.y
            -- Normalize to a single cardinal step along the dominant axis, matching how every other
            -- directional effect in this game reads a caster->target vector.
            if math.abs(dx) >= math.abs(dy) then
                dx, dy = (dx > 0 and 1) or (dx < 0 and -1) or 0, 0
            else
                dx, dy = 0, (dy > 0 and 1) or (dy < 0 and -1) or 0
            end
            local behind = fx.unitAt(fx.target.x + dx, fx.target.y + dy)
            if not behind then return end
            -- Half again for each other dagger in the grid, floored so a lone Throughline still spills
            -- for something. The spill carries the same tags, so it bleeds too -- which is the whole
            -- reason to run this over a bigger knife.
            local knives = fx.adjacentMatching({ tag = "dagger" })
            local spill = math.floor((fx.amount or 0) * (0.4 + 0.2 * knives))
            if spill < 1 then return end
            fx.damage(behind, { amount = spill, inflicts = { id = "status_bleed" } })
        end,
    },
}
