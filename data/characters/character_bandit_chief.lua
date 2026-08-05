-- The Undercroft's ELITE rung (docs/bestiary.md): the body a bandit pack is shaped around, and a
-- THIEF made flesh (data/disciplines/thief.lua). He used to carry one iron sword and 105 health, which
-- is a stat block rather than a discipline -- you fought him and learned nothing about what the rogue
-- shelf becomes when it is earned.
--
-- HE KEEPS THE IRON SWORD, and that is deliberate. There is no chief's blade on the rogue shelf --
-- every priced rogue weapon is a knife -- and reaching for one would have made him a cutpurse with a
-- health pool. He carries exactly what his men carry (data/characters/character_bandit.lua); what
-- makes him the chief is the other hand. The blade is the cheap thing about him.
--
-- WHAT HE DEMONSTRATES is the Thief's whole argument: he does not kill you, he TAKES from you, and
-- everything already taken makes the next blow worth more. Shakedown lays the debuff on, Sap drinks
-- the stamina out of whoever is still standing, and the Cutpurse's Tally -- his relic, and the item
-- worth beating him for -- prices every blow by how much has been lifted off the target already. Three
-- items that read as one sentence, which is the Elite rung's entire job.
--
-- Every piece of it is priced and unbound, so it drops off him (models/spoils.lua draws from the
-- carried pool): the discipline gate is a purchase gate, not an equip gate, so the Tally is usable the
-- moment it falls even though the Undercroft will not sell you one until you have earned the shelf.
return {
    name = "Bandit Chief",
    kind = "humanoid",
    tier = 3,
    class = "rogue",
    discipline = "thief",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/bandit_chief.png",
    stats = {
        health = 105, mana = 0, stamina = 20,
        damage = 22, magicDamage = 0,
        defense = 12, magicDefense = 6,
        movement = 4,
        speed = 4,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. The Tally sits in the centre with the
    -- two lifts around it -- it is the item the other two feed, so it reads as the middle of his kit
    -- in the same way it is the middle of his fight. Stat line untouched: the discipline arrives as
    -- items, not as numbers.
    startingItems = {
        "weapon_iron_sword",   "ability_shakedown",         "ability_sap",
        false,                 "utility_cutpurse_tally",    false,
        "armor_leather_armor", "consumable_healing_potion", false,
    },
    defaultAction = "weapon_iron_sword",
    -- The two items that ARE this unit, in one glance: its weapon and its signature verb.
    -- Draft mode strips a bought body down to exactly these (models/draft_chassis.lua).
    signatureWeapon  = "weapon_iron_sword",
    signatureAbility = "ability_shakedown",
    -- Basic tactics (models/ai.lua), top-to-bottom, first match wins. The order IS the discipline:
    -- take first, then price what you took.
    ai = {
        -- 1. Shake down anyone not already carrying the debuff. This is the setup half -- it is what
        -- the Tally counts -- and `lacks_status` means he works his way along the party rather than
        -- robbing the same body twice. A foe already shaken falls through to the rules below.
        { priority = "high", act = "cast", item = "ability_shakedown",
          when = { subject = "any_foe", test = "lacks_status", value = "status_shaken_down" } },
        -- 2. Sap the wounded: damage plus their stamina into his own, which is how a fight against him
        -- gets quieter the longer it runs. Aimed at the foe closest to falling, so the drain lands on
        -- whoever can least afford to be unable to swing.
        { priority = "high", act = "attack", item = "ability_sap", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        -- 3. Otherwise the sword, into whatever is closest to falling -- and by now the Tally is
        -- reading a stack of debuffs somebody else's turn put there.
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
