-- The general of Wrath, and the first of the seven the Colosseum's line was always walking toward
-- (see docs/story.md). Enemy blueprint; the objective of data/quests/general_wrath.lua.
--
-- Her whole fight is one rule, and it is in `traits`: every blow she survives is added to her next
-- one (data/traits/wrath_rising.lua). Her opening stats are deliberately modest for a boss -- a
-- Warlord hits harder on turn one -- because the danger is not what she starts as. Trade with her and
-- you are building her. The counterplay is burst, control, and finishing before the rage compounds.
--
-- Her mail carries the same rule for whoever lifts it off her (data/items/armor/armor_mail_of_the_unappeased.lua).
return {
    name = "Ira, the Unappeased",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_wrath.png",
    portrait = "assets/portraits/general_wrath.png", -- large VN portrait for conversations (falls back if missing)
    stats = {
        health = 180, mana = 0, stamina = 30,
        damage = 18, magicDamage = 0, -- low, and rising
        defense = 12, magicDefense = 6, -- deliberately soft to magic: the burst answer is real
        movement = 4,
        speed = 4,
    },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Her rule rides on the Unappeased
    -- Heart relic in the center (data/items/utility/utility_unappeased_heart.lua): a bound item, and
    -- `bound` keeps it unstealable -- a rogue can't lift her whole fight off her in one grab. Her greataxe
    -- sits beside it.
    startingItems = {
        false, false,                  false,
        false, "utility_unappeased_heart", "weapon_crimson_greataxe",
        false, false,                  false,
    },
    -- Basic tactics (models/ai.lua): unappeased and rising, she swings the greataxe at the foe already
    -- closest to falling -- press the wounded.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
