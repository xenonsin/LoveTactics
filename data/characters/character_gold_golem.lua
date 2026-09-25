-- THE GOLD GOLEM: Greed's rung-1 spare elite (reviewed over two rounds, 2026-09-25, "The Golems of
-- Greed"). A statue of solid gold. Round 2 denied its first body ("can't be weaker than the normal
-- golems"), so it carries every Earth Golem rule and more of each (utility_living_gold):
--
--   Delve               the Delver's own Delve, as creature kit -- it goes under too ("Yes, it Delves")
--   Strike the Vein     the hole it leaves is gold, or one time in three lava
--   Gold Plate          four plates, +2 Defense each; an impact blow knocks one off as a COIN HEAP
--   Regild              it eats heaps: heals 15% and takes the gold back on as a plate, no cap
--   Gold Calls to Gold  every heap within 4 slides a tile toward it at its turn's start (round 2's pick)
--   Chipped Gold        every blow that lands pays 3 gold into the spoils
--   The Hoard Falls Out four coin heaps where it falls
--
-- So the fight is a race for the gold on the floor: every heap the company loots is armour the golem
-- does not get, and every plate the mace knocks off is gold both sides want. Gold conducts: lightning
-- is its second weakness, milder than the first, so a caster company is not locked out.
--
-- `boss`, as the King Slime is, and never an `assassinate` mark (encounter_greed_the_gold_golem).
return {
    name = "Gold Golem",
    race = "construct",
    tier = 4,
    boss = true,
    sprite = "assets/chars/gold_golem.png",
    stats = {
        health = 200, mana = 0, stamina = 24,
        staminaRegen = 3,
        damage = 16, magicDamage = 0,
        defense = 9, magicDefense = 5, -- 17 with its four plates on
        movement = 3,
        speed = 2,
        skill = 5, luck = 0,
    },
    -- Summed to zero like every creature hide, and round 2's "no weaker": a harder shell than the Earth
    -- Golem's and a deeper dent under the mace.
    resist = { slash = 3, pierce = 3, impact = -6, lightning = -3 },
    startingItems = {
        "weapon_stone_fists", "ability_golem_delve", "utility_living_gold",
        false,                false,           false,
        false,                false,           false,
    },
    -- Its two shelved pieces first, then the three trophies (round 2: "everything").
    drops = { "utility_heart_of_gold", "utility_gilt_plating",
        "utility_lodestone", "utility_spilled_purse", "utility_golden_ballast" },
    defaultAction = "weapon_stone_fists",
    signatureWeapon = "weapon_stone_fists",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
        -- With nothing in reach it walks for the gold (Regild: models/ai.lua's heap walk reads
        -- `eatsHeaps`) -- unless the gold is far and a foe is near enough to come up beside.
        { priority = "normal", act = "cast", item = "ability_golem_delve",
          when = { subject = "any_foe", test = "exists" } },
    },
}
