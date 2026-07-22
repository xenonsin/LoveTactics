-- The general of Greed, and the end of the Undercroft's line (docs/story.md, "The Undercroft"). Enemy
-- blueprint; the objective of data/quests/general_greed.lua. The finale (data/quests/the_gate_below.lua)
-- already reserves a slot for her -- "general_greed" sits in its requiredQuests.
--
-- WHO SHE IS: a debtor once, ruined and owned -- the thing at the bottom of an institution like her own.
-- She pacted with the Demon Lord not for power but never to owe again -- to be the one everyone owes,
-- forever -- and the bargain's cruelty is Midas's exactly: everyone does, and she can keep or feel or
-- spend none of it. She is the world's creditor and starves at her own table; being owed is the only
-- sensation the pact left her, so she must keep calling it in.
--
-- HER RULE rides on the Purse in her grid (a blueprint's own `traits` field is never collected; only an
-- item's is -- models/trait.lua): the Golden Touch -- "lifts the kit out of your hands mid-fight"
-- (data/items/utility/utility_bottomless_purse.lua). She takes the THING (your gear, turned to gold),
-- which keeps her the clean side of the Greed/Envy line: Livia's Covet takes the thing's PROPERTY and
-- would rather you had neither.
--
-- SHIPPED FIDELITY: the bare take-a-thing is what ships. The whole GOLD ECONOMY the chapter designs --
-- gold as her ward, the cost of her every action, and board-loot; her hired blades bought with it; and
-- the bankruptcy-triggered two-phase transform into the Midas-horror -- is a bespoke finale subsystem,
-- deferred new work. Statted here as an ordinary single-phase general with a real health pool rather than
-- the gold-warded soft mortal the full design calls for.
--
-- `assassinate` is the honest objective -- her retinue is a wall to pass, not a thing to grind.
return {
    name = "Aurea, the Ever-Owed",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/general_greed.png",
    portrait = "assets/portraits/general_greed.png", -- large VN portrait for conversations (falls back if missing)
    stats = {
        health = 200, mana = 40, stamina = 15,
        staminaRegen = 2,
        damage = 14, magicDamage = 0, -- she does not duel; she takes, and she buys blades (deferred)
        defense = 13, magicDefense = 11,
        movement = 3,
        speed = 3, -- slow: a hoard does not chase
    },
    -- Her loadout as the 3x3 grid (row-major); false = an empty cell. Her rule rides on the Bottomless
    -- Purse in the center (unstealable). Around it: her own blade (its bleed her one free action) and a
    -- second lift -- she takes with both hands.
    startingItems = {
        "ability_pickpocket",      false,                     false,
        "weapon_kingsblood_dagger", "utility_bottomless_purse", false,
        false,                     false,                     false,
    },
    defaultAction = "weapon_kingsblood_dagger",
    ai = {
        { priority = "high", act = "attack", item = "weapon_kingsblood_dagger",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
