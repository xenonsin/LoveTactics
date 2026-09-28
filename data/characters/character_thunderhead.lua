-- THE THUNDERHEAD: a Blaze and an Arc, fused (reviewed 2026-09-27/28, "Fire, Lightning, and Dirty Thunder"). The
-- storm an eruption makes -- lightning in an ash column is a real thing, a dirty thunderstorm -- and the elite of
-- the fight named for it (encounter_wrath_dirty_thunder). It is never placed: it is made, at the end of any turn a
-- Blaze and an Arc stand side by side (models/storm.lua), with its bar filled to the share of health the two of
-- them had left.
--
--   ITS FIRE CARRIES ITS LIGHTNING  while it stands, every fire on the board conducts lightning as water does
--   ASHFALL        at the end of its turn, ash on 3 tiles toward its nearest foe: sight-sealing, and it Blinds
--   THE TEAR       below half, or on a blow that would fell it, it tears back into the Blaze and the Arc, each at a
--                  quarter of its bar -- once; if they fuse again, the second storm fights to the end
--   ERUPTION       once, at a third: the tiles beside it become lava and every body standing in fire is struck
--   ITS KIT        the Arc's forking bolt, Pyroclast (whichever of fire and lightning you resist less), and the
--                  Flashpan (its first bolt a turn Blinds)
--
-- It flies, as a cloud does (the organ's `flying` tag), so the lava is nothing to it and the eruption does not take
-- it. Tier 3, 140 health, under the tier-3 cap of 154 beside the Minotaur's 150. `boss`, off the execute and Charm
-- tables like every elite of the deeps.
return {
    name = "Thunderhead",
    race = "elemental",
    tier = 3,
    boss = true,
    sprite = "assets/chars/thunderhead.png",
    archetype = "aggressive",
    stats = {
        health = 140, mana = 40, stamina = 30,
        staminaRegen = 4, manaRegen = 4,
        damage = 4, magicDamage = 18,
        defense = 6, magicDefense = 10,
        movement = 4,
        speed = 6,
        skill = 6, luck = 4,
    },
    resist = { fire = 4, lightning = 4, water = -6 },
    startingItems = { "weapon_arc_bolt", "ability_pyroclast", "utility_flashpan", "utility_the_thunderhead" },
    -- Round 2's three, each off one of its rules: the combination, the eruption, the fusion.
    drops = { "ability_pyroclast", "utility_eruption_stone", "ability_ball_lightning" },
    defaultAction = "weapon_arc_bolt",
}
