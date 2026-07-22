-- The general of Lust, and the end of the Cathedral's line (docs/story.md, "The Cathedral"). Enemy
-- blueprint; the objective of data/quests/general_lust.lua. The finale (data/quests/the_gate_below.lua)
-- already reserves a slot for her -- "general_lust" sits in its requiredQuests.
--
-- WHO SHE IS: a human who made a pact with the Demon Lord for demonic power, then INFILTRATED the
-- Cathedral and took the seat of its most revered living Saint -- the one who blesses (bloods) every
-- soldier. The "holy" magic in the anointed is her blood; she has seeded the whole order as a sleeper
-- army. She is not Amana's kin and not a redeemed oblate -- an outsider at the altar.
--
-- Her whole fight is one rule, and it rides on the reliquary in her grid (a blueprint's own `traits`
-- field is never collected; only an item's is -- models/trait.lua): she takes what you hold back
-- (data/traits/trait_rapture.lua). Every blow draws off the stamina and mana the target was hoarding and
-- takes it into herself as health -- so a party husbanding resources for the big turn feeds her the whole
-- time. The counterplay is the sin read as tactics: SPEND, let nothing sit unspent near her. The one unit
-- she can never draw from is Amana (character_amana.lua) -- an unblooded acolyte, carrying none of
-- Luxuria's blood, so the taking finds no purchase on her (data/traits/trait_devotion_unbidden.lua).
--
-- At the finale she offers the one thing that could break her foil -- Amana's birth-name, the self the
-- Cathedral took (she keeps the intake rolls). Not a seizure -- Amana's refusal is a choice. Statted as a
-- hungry duelist rather than a wall: middling everything, kept alive by what she drinks off you.
-- `assassinate` is the honest objective -- her guard is a wall to pass, and every turn grinding it feeds her.
--
-- TODO (see docs/story.md + the plan): the finale kit is not yet built. She should also DRAIN-AND-TURN
-- (a blooded unit she has drained enough flips to her side; Amana, unblooded, is the hard counter), and
-- the fight is TWO-PHASE -- the human Saint sheds into her demonic form at a health threshold. Both are
-- new work over the shipped Rapture rule.
--
-- Her reliquary carries her rule for whoever lifts it (data/items/utility/utility_reliquary_unbidden.lua).
return {
    name = "Luxuria, the Unbidden",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_lust.png",
    portrait = "assets/portraits/general_lust.png", -- large VN portrait for conversations (falls back if missing)
    stats = {
        health = 200, mana = 60, stamina = 25,
        staminaRegen = 2,
        damage = 14, magicDamage = 10, -- middling; the drink is what keeps her standing
        defense = 14, magicDefense = 14,
        movement = 3,
        speed = 4,
    },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Her rule rides on the Reliquary of
    -- the Unbidden in the center (bound, unstealable), the censer of ashes -- the lust family read from the
    -- taking side (data/items/weapon/weapon_censer_of_ashes.lua) -- beside it.
    startingItems = {
        false, false,                        false,
        false, "utility_reliquary_unbidden", "weapon_censer_of_ashes",
        false, false,                        false,
    },
    -- Basic tactics (models/ai.lua): a hungry duelist finishes what she has drained -- press the foe
    -- already closest to falling. (Her Rapture rule rides on the reliquary; this only picks the mark.)
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
