-- The column itself, on the road legs of the relief of Highwatch (data/quests/relief_column.lua).
-- Spawned party-side under AI control through an ENCOUNTER's `allies` (states/battle.lua's specFor
-- reads `def.allies`, the same seam a quest objective uses), and named by both the `who` and the
-- `protect` of each road fight's objective.
--
-- Deliberately a separate blueprint from character_caravan_master, who is the same fiction with the
-- opposite posture. The driver `escort`s -- it walks for the exit and never stops to fight, because
-- on the mountain road the column is trying to LEAVE, and its arrival is the win condition; the
-- killing is the party's job, not the driver's. The master holds where he stands at the gate,
-- because by then there is nowhere further up to go.
--
-- One caveat on that walk: it will NOT stroll on while a demon is breathing down its neck. The
-- escort posture's `advance` heads for the exit, not the enemy, but the exit can lie past a foe, and
-- a driver that keeps trundling forward would hand itself over. So a single `wait` rule sits on top
-- of the empty escort list: while any foe is within CLOSE_RANGE tiles it stands its ground and lets
-- the party clear the road; only once the way is clear of nearby demons does it drop through to
-- `advance` and press on. It still never moves TOWARD a foe -- it either walks for the exit or holds.
--
-- One blueprint per posture rather than a per-spawn override: the same reason
-- character_bastion_sworn is not character_knight with a flag.
--
-- Fragile and slow, and it carries nothing, so it swings the default unarmed weapon. It is a clock,
-- not a combatant: every turn it advances is a turn the party has to have cleared the road ahead.
return {
    name = "Caravan Driver",
    archetype = "escort",
    sprite = "assets/chars/caravan_master.png",
    stats = {
        health = 38, mana = 0, stamina = 8,
        staminaRegen = 1,
        damage = 4, magicDamage = 0,
        defense = 3, magicDefense = 2,
        movement = 4,
        speed = 2,
    },

    -- Hold while the enemy is near, advance only when the coast is clear. `within` matches when ANY
    -- foe sits inside the range, so a lone demon three tiles off is enough to stop the column. When no
    -- foe is that close, this rule doesn't fire and the escort posture's `advance` fallback carries the
    -- driver on toward the exit (never toward the enemy). 3 tiles ~ one demon step of breathing room;
    -- raise it to make the driver more skittish, lower it to make it press on through closer danger.
    ai = {
        { act = "wait", when = { subject = "any_foe", test = "within", value = 3 } },
    },
}
