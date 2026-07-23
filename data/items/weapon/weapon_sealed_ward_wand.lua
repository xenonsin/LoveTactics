-- A wand, so it reaches at range and needs only a direction (docs/weapons.md) -- and it is the only wand
-- that is aimed at a FRIEND. It deals nothing to anybody; it lays a Sealed Ward (status_sealed_ward) on
-- an ally, which refuses the next single-target spell aimed at them outright.
--
-- Quest-only: `class` with no `price`.
--
-- A DELIBERATE DEVIATION and named as one: the family contract says a wand is ranged magical damage, and
-- this keeps the range, the school and the "needs only a direction" freedom while dropping the damage
-- entirely. What it keeps is what actually distinguishes a wand from a staff -- reach, and the fact that
-- the reach costs nothing to set up.
--
-- Why the shelf needed one: the Arcanum's whole answer to an enemy caster has been to out-damage them,
-- and there has been no way at all to protect a specific body from a specific spell. A Sealed Ward is
-- exactly that -- it does not reduce anything, it REFUSES one working, so the enemy's biggest single-
-- target cast simply does not happen. Against a boss whose one dangerous spell you can see coming on the
-- timeline, one turn of this is worth more than any bolt in the game.
--
-- It answers single-target only. A blast, a hazard, an aura or a melee blow all go straight through it,
-- which is what keeps it a read on the enemy's kit rather than a general-purpose shield.
return {
    name = "Wand of the Sealed Ward",
    description = "Seals an ally at range: the next single-target spell aimed at them is refused outright. Deals no damage.",
    flavor = "The Arcanum is very clear that it is not a shield. A shield would have to be hit.",
    sprite = "assets/items/sealed_ward_wand.png",
    type = "weapon",
    tags = { "wand", "magical", "arcane", "ranged" },
    class = "mage",
    activeAbility = {
        target = "ally",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 8 },
        damage = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, -- it is not a bolt; see the header
        effect = function(fx)
            local t = fx.target
            if not t or not t.alive then return end
            -- Longer with the forge, as every warding cast in the catalog is: an upgrade buys the ward
            -- more time to be needed, never a second refusal.
            fx.applyStatus(t, "status_sealed_ward", { duration = 12 + 2 * fx.level })
            fx.log("action", string.format("%s seals %s.",
                (fx.user.char and fx.user.char.name) or "Unit",
                (t.char and t.char.name) or "an ally"))
        end,
    },
}
