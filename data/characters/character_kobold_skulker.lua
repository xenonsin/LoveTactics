-- THE KOBOLD SKULKER, rung 1: the kobold line's chaff. Approved as pitched (2026-09-24, "The Kobolds of
-- Greed"), its drop reworked in round 2 ("add something" -- Harry).
--
-- A SPEAR AND SCURRY (utility_scurry): it hits, steps a tile back for free, and leaves the foe Harried for
-- whoever strikes next. What it IS comes off the race (data/races/kobold.lua): Pack -- every kinsman
-- beside its target is +2 on the blow -- and Devotion, the Dragon's Eye near its dragon. Three of them
-- round one body is the problem the company has to answer, and the answer is where the company stands.
--
-- A SKIRMISHER (fighter root), the house that strikes and moves on -- its footwork is the discipline's.
-- `class = "fighter"` for the reason the Dwarf Delver gives: a lighter table lags the enemy scaling at
-- depth. Brittle by its own line (Defense 1) where the review asked for brittleness on the race: the racial
-- stat budget is two points and the race spends them on its feet (data/races/kobold.lua).
return {
    name = "Kobold Skulker",
    race = "kobold",
    tier = 1,
    class = "fighter",
    discipline = "skirmisher",
    sprite = "assets/chars/kobold_skulker.png",
    archetype = "aggressive",
    stats = {
        health = 20, mana = 0, stamina = 16,
        staminaRegen = 3,
        damage = 9, magicDamage = 0,
        defense = 1, magicDefense = 1,
        movement = 4, -- 5 after the race
        speed = 5,    -- 6 after the race
        skill = 6, luck = 5,
    },
    startingItems = {
        "weapon_iron_spear", "utility_scurry", false,
        false,               false,            false,
        false,               false,            false,
    },
    drops = { "utility_scurry" },
    defaultAction = "weapon_iron_spear",
    signatureWeapon = "weapon_iron_spear",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
