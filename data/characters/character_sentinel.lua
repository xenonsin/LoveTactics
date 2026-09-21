-- Sentinel exemplar (knight subclass). Intercept: redirect adjacent allies' incoming hits onto
-- yourself. Met as a mentor -- the Knight in Grey shows this discipline in its unlock quest, but that
-- body (character_grey_knight) is a deliberately minimal, story-disguised encounter unit, so the
-- discipline exemplar is authored here with the full Sentinel kit. Kit from data/classes/sentinel.lua.
return {
    name = "Sentinel",
    race = "human",
    tier = 3,
    sprite = "assets/chars/sentinel.png",
    class = "knight",
    discipline = "sentinel",
    -- Stands between the foe and the wounded ally; holds until the fight comes (models/ai.lua `defensive`).
    archetype = "defensive",
    stats = {
        health = 100, mana = 20, stamina = 16,
        staminaRegen = 2,
        damage = 14, magicDamage = 4,
        defense = 15, magicDefense = 9,
        movement = 4,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 2,
    },
    -- THE GRID IS THE KIT, and two cells of it were dead.
    --
    -- Single Combat declares `requiresAdjacent = { type = "weapon" }` and was authored in the
    -- top-right cell, whose neighbours are the two abilities beside and below it -- so the
    -- discipline's duel verb was refused by Combat.itemBlockReason in every fight this body has ever
    -- stood in. It sits beside the sword now, which is the whole of that fix.
    --
    -- ...and the Bulwark was a SECOND SHIELD on a body already carrying one. It and the Standing Debt
    -- both swap Wait for Defend and both cost a point of movement, so the pair bought one stance twice
    -- and paid double for it -- while INTERCEPT, the thing this discipline IS (data/classes/sentinel.lua,
    -- and the description on its own card), was on no item in the grid and therefore on no body here at
    -- all: `unit.guard` was nil. The Warden's Oath IS that mechanic (armor_wardens_oath, `class =
    -- "sentinel"`), it costs the same point of movement the Bulwark did, and it is the difference
    -- between an exemplar and a knight carrying a sentinel's shopping list.
    startingItems = {
        "weapon_iron_sword",   "ability_single_combat", "ability_shared_burden",
        "ability_straw_sentry", "utility_lent_aegis",   "utility_unyielding_seal",
        "armor_wardens_oath",  "consumable_healing_potion", "armor_standing_debt",
    },
    drops = {
        "weapon_brackish_lance",
        "weapon_sworn_lance",
        "utility_bared_nerve",
        "weapon_boar_spear",
        "utility_wardens_writ",
    },
    defaultAction = "weapon_iron_sword",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua), so the
    -- rest of its kit is gear the player chose and read rather than nine inherited unknowns.
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "ability_shared_burden",
    -- Take the wounded ally's burden onto itself before anything else.
    ai = {
        { priority = "urgent", act = "support", item = "ability_shared_burden", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.6 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
