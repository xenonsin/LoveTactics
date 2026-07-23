-- The column itself, on the road legs of the relief of Highwatch (data/quests/relief_column.lua).
-- Spawned party-side under AI control through an ENCOUNTER's `allies` (states/battle.lua's specFor
-- reads `def.allies`, the same seam a quest objective uses), and named by both the `who` and the
-- `protect` of each road fight's objective.
--
-- Deliberately a separate blueprint from character_caravan_master, who is the same fiction with the
-- opposite posture. The driver `escort`s -- it walks for the exit every turn and never stops to
-- fight, because on the mountain road the column is trying to LEAVE, and its arrival is the win
-- condition; the killing is the party's job, not the driver's. The master holds where he stands at
-- the gate, because by then there is nowhere further up to go.
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
        movement = 3,
        speed = 2,
    },
}
