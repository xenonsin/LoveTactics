-- A bear. Like data/characters/pig.lua this is a SHAPE rather than a combatant -- worn by a hunter who
-- casts Wild Shape: Bear (data/items/ability/ability_wild_shape_bear.lua), never recruited or fought
-- as itself.
--
-- The bear is the hunter's ANCHOR shape, and it is the deliberate opposite of the wolf's. Where the
-- wolf trades the hunter's bow for reach across the board, the bear trades it for the right to stand
-- somewhere and be immovable: the best raw defense of any body in the game, damage that reads as a
-- greatsword, and a movement of 2 that means wherever it plants itself is where the fight is. A hunter
-- who wants to be a knight for a while buys it here.
--
-- The health/mana/stamina below are placeholders and are never used: a transform carries the original
-- body's pools across verbatim (see models/transform.lua). The bear does NOT bring a bear's health --
-- that is the rule that keeps wild shape from being a second life bar. What it brings is the claws,
-- the hide, and the feet, and those it brings in full.
return {
    name = "Dire Bear",
    sprite = "assets/chars/dire_bear.png",
    stats = {
        health = 1, mana = 0, stamina = 1, -- placeholders: the hunter's own pools are carried across
        staminaRegen = 3, -- a big engine: it fuels the claws, which are not cheap to swing
        damage = 20, magicDamage = 0,
        defense = 14, magicDefense = 4, -- a hide like plate, and a head full of nothing about magic
        movement = 2, -- ponderous: the bear does not chase, it arrives and stays
        speed = 2,
    },
    startingItems = { "weapon_great_claws", "utility_feral_instinct" },
    -- Basic tactics (models/ai.lua): under auto-battle the anchor shape still knows a kill -- press the
    -- foe closest to falling. The hunter driving the shape overrides this.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
