-- THE DWARF HEARTHGUARD, rung 2: the line's shield. Reworked on review (2026-09-24): "don't defend heaps,
-- defend allies that are going for heaps". So it does not stand on the gold -- it walks beside whichever
-- kinsman is nearest to some (the `shadow` walk, models/ai.lua) and takes the blow meant for him.
--
-- A SENTINEL (knight root): Warden's Oath takes the first hit each turn aimed at an adjacent ally in that
-- ally's place, which is the whole reason a company cannot simply shoot the dwarf running for the heap.
-- The answer is to hit the Hearthguard first, or to hit the runner twice.
return {
    name = "Dwarf Hearthguard",
    race = "dwarf",
    tier = 2,
    class = "knight",
    discipline = "sentinel",
    sprite = "assets/chars/dwarf_hearthguard.png",
    archetype = "shadow",
    coffer = 15,
    stats = {
        health = 50, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 13, magicDamage = 0,
        defense = 6, magicDefense = 4, -- 7 after the race
        movement = 5, -- 4 after the race; the Oath's plate takes one more
        speed = 3,
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_axe", "armor_wardens_oath", false,
        false,             false,                false,
        false,             false,                false,
    },
    drops = { "armor_wardens_oath" },
    defaultAction = "weapon_iron_axe",
    signatureWeapon = "weapon_iron_axe",
    ai = {
        { priority = "high", act = "attack", targetPref = "gilded",
          when = { subject = "any_foe", test = "has_status", value = "status_gilded" } },
    },
}
