-- Enemy character blueprint. Reuses the party-character schema (models/character.lua):
-- flat base stats, resource stats split into { max, current } on instantiate. Enemies
-- live alongside party members and are placed on the far side of a battle arena.
--
-- The Undercroft's LINE rung (docs/bestiary.md): one real weapon, no ability, the body a fight is made
-- of. Its chief is the Elite that leads it (data/characters/character_bandit_chief.lua), and the pair
-- is the rung split working -- you read the beaters' iron swords, then read what the man behind them
-- is holding instead.
--
-- IT DECLARES NO `class`, AND THAT IS LOAD-BEARING RATHER THAN AN OVERSIGHT. A bandit is a rogue in the
-- fiction, and the obvious tidy-up is one line saying so. It is a balance change: `class` is the growth
-- table an enemy climbs (models/growth.lua, Growth.creditClass), and the rogue table buys +2 damage a
-- level against the knight table's +2 defense. The two cancel exactly, so a rogue-classed body's
-- post-mitigation damage never rises at all while its target gains +6 health a level -- a level-20
-- bandit stops being able to hurt an armoured party, which tests/enemy_scaling_spec.lua catches. The
-- classless fallback (Growth.NEUTRAL_CLASS, fighter: +3 damage) clears the knight's armour by a point a
-- level, which is the only reason ordinary stock scales at all.
--
-- So the shelf a body fights from is declared only where something reads it -- on the Elites, which
-- name a `discipline` and carry its stock. The chief can afford to be a rogue precisely because his kit
-- scales on DEBUFFS rather than on raw damage; a mook with one sword cannot.
return {
    name = "Bandit",
    kind = "humanoid",
    tier = 2,
    sprite = "assets/chars/bandit.png",
    stats = {
        health = 42, mana = 0, stamina = 13, -- resource stats
        damage = 12, magicDamage = 0,         -- flat stats
        defense = 6, magicDefense = 3,
        movement = 4, -- number of spaces this character can move
        speed = 4,
    },
    startingItems = { "weapon_iron_sword" },
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
