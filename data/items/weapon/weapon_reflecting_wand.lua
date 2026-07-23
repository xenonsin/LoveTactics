-- A wand, so it reaches at range and needs only a direction (docs/weapons.md), and the second of the two
-- that are aimed at a friend. It grants an ally Mirrored (status_reflect_magic): the next single-target
-- spell thrown at them rebounds onto the caster who threw it.
--
-- Quest-only: `class` with no `price`.
--
-- The pair to data/items/weapon/weapon_sealed_ward_wand.lua, and the difference between them is the whole
-- reason both exist. A Sealed Ward REFUSES a spell -- the working simply fails, and the enemy has spent a
-- turn. This one RETURNS it, so the enemy has spent a turn and taken their own best cast in the face.
-- Refusal is the safe read and reflection is the greedy one: against a caster whose big spell would kill
-- your ally outright, sealing is correct, and against one whose spell is merely painful, mirroring wins
-- the fight.
--
-- It also pairs across shelves with armor_reflecting_shield, which does the same thing for physical blows
-- off the knight's Defend. One word -- mirrored -- split between the two schools and the two shelves, and
-- a party carrying both can point it at whichever half of the enemy's kit is worse.
--
-- Single-target only, like every reflection here: a blast passes straight through, which is what keeps it
-- a read on the enemy caster's kit rather than a blanket answer to magic.
return {
    name = "The Reflecting Wand",
    description = "Mirrors an ally at range: the next single-target spell aimed at them rebounds onto its caster.",
    flavor = "It does not argue with the spell. It agrees with it, and then asks where it was going.",
    sprite = "assets/items/reflecting_wand.png",
    type = "weapon",
    tags = { "wand", "magical", "arcane", "ranged" },
    class = "mage",
    activeAbility = {
        target = "ally",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 9 },
        damage = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },
        effect = function(fx)
            local t = fx.target
            if not t or not t.alive then return end
            fx.applyStatus(t, "status_reflect_magic", { duration = 12 + 2 * fx.level })
            fx.log("action", string.format("%s turns the air around %s.",
                (fx.user.char and fx.user.char.name) or "Unit",
                (t.char and t.char.name) or "an ally"))
        end,
    },
}
