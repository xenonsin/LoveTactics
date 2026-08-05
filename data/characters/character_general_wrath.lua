-- The general of Wrath, and the first of the seven the Colosseum's line was always walking toward
-- (see docs/story.md, docs/wrath-line-beats.md). Enemy blueprint; the objective of
-- data/quests/colosseum/quest_colosseum_slot_10.lua.
--
-- WHO SHE IS. The Perennial's manufactured champion -- trained since birth, owned all her life, made
-- to win and to kill on the house's schedule and never her own. The one thing she was never given is
-- the one thing she wanted: to be free. The sand was the only place she ever moved on her own accord,
-- so she fought superbly, and her SULLEN wrath -- resentment held down for years -- was the secret
-- engine of her ferocity. Then she CHOSE the pact: promised freedom and the strength to take it, she
-- bargained with the Demon Lord herself and got an uncontrollable rage instead -- a deeper cage with
-- no door. This is phase one, the woman who still wants out; the bargain come due is her second form
-- (character_general_wrath_demon).
--
-- HER FIGHT is one rule, and it rides on her Unappeased Heart relic (not `traits` -- character-level
-- traits are never instantiated; only grid items grant them): her damage rises as her health FALLS,
-- plus a per-blow contact term (data/traits/trait_wrath_rising.lua). Her opening stats are deliberately
-- modest for a boss -- a Warlord hits harder on turn one -- because the danger is not what she starts
-- as. Trade with her and you loose the thing she cannot control. The counterplay is burst, control, and
-- ending it before the rage rises -- the same lesson every bout on the sand has taught since the debut.
--
-- Her mail carries the same rule for whoever lifts it off her (data/items/armor/armor_mail_of_the_unappeased.lua).
return {
    name = "Ira, the Unappeased",
    kind = "humanoid",
    tier = 4,
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
