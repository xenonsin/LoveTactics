-- THE FAMILIAR, rung 1: a vampire's bat (Wrath's vampires, round 1; "many bats ok"). A flier with a weak bite that
-- opens a vein, and a BLOOD COURIER: what it drinks goes to the nearest vampire, which resets its Thirst and heals
-- as if it had bitten (trait_blood_courier). Every vampire can Wing-Swap with any Familiar on the board, so a bat
-- that has flown to the company's backline is where a vampire will be next.
--
-- The company's own is the Familiar's Whistle: the same bat, and its drink heals whoever called it.
return {
    name = "Familiar",
    race = "beast",
    tier = 1,
    sprite = "assets/chars/familiar.png",
    archetype = "skirmish",
    stats = {
        health = 14, mana = 0, stamina = 16,
        damage = 4, magicDamage = 0,
        defense = 1, magicDefense = 2,
        movement = 6,
        speed = 6,
        skill = 3, luck = 6,
    },
    -- INNATE MITIGATION: leather and hollow bone. A blade and an arrow pass through the wing; a club takes it out
    -- of the air.
    resist = { slash = 1, pierce = 1, impact = -2 },
    startingItems = { "weapon_bat_fangs", "utility_blood_courier" },
    drops = { "ability_familiars_whistle" },
    defaultAction = "weapon_bat_fangs",
}
