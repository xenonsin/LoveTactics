-- The general of Wrath, and the first of the seven the Colosseum's line was always walking toward
-- (see docs/story.md). Enemy blueprint; the objective of data/quests/general_wrath.lua.
--
-- Her whole fight is one rule, and it is in `traits`: every blow she survives is added to her next
-- one (data/traits/wrath_rising.lua). Her opening stats are deliberately modest for a boss -- a
-- Warlord hits harder on turn one -- because the danger is not what she starts as. Trade with her and
-- you are building her. The counterplay is burst, control, and finishing before the rage compounds.
--
-- Her mail carries the same rule for whoever lifts it off her (data/items/armor/mail_of_the_unappeased.lua).
return {
    name = "Ira, the Unappeased",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_wrath.png",
    stats = {
        health = 260, mana = 0, stamina = 120,
        damage = 18, magicDamage = 0, -- low, and rising
        defense = 12, magicDefense = 6, -- deliberately soft to magic: the burst answer is real
        movement = 4,
        speed = 4,
    },
    traits = { "wrath_rising" },
    startingItems = { "crimson_greataxe" },
}
