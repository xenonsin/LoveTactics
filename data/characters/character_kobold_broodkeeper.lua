-- THE KOBOLD BROODKEEPER, rung 2: the egg's guard. Approved in round 1 (2026-09-24) and reworked in round 2
-- (2026-09-25) once the eggs stopped being fed gold: it guards the BROODERS, not the carriers.
--
-- IT STANDS AT THE EGG. `guards` names the Dragon Egg and `guardRadius = 1` holds that post beside it rather
-- than near it (AI.post), so every turn it ends there it broods the egg itself -- three of its turns and the
-- egg hatches, which is the clock a Clutch fight runs on. Warden's Oath takes the first blow each turn aimed
-- at an ally beside it, and beside it are the egg and whoever else is brooding. With the egg gone it guards
-- whoever its side can least afford to lose, which is the ordinary `defensive` reading.
--
-- IT WEARS THE SENTINEL'S OATH AND GROWS ON THE FIGHTER TABLE (`class = "fighter"`, no discipline). Pitched
-- as a sentinel, and first authored as one; measured, the knight table's defense at depth made it a wall
-- -- the Clutch ran 32 unit-turns and the Choir 49 against a road-fight budget of 22, the same shape the
-- dwarves' Hearthguard fights sit on the slow backlog for -- and on the fighter table they run 6 and 12.
-- A body claiming a discipline has to grow in that discipline's root, so the claim goes and the Oath
-- stays (the Delver's and the Fen Lancer's reason for their own `fighter`). Drops the Dragon Egg, which the
-- company broods for itself.
return {
    name = "Kobold Broodkeeper",
    race = "kobold",
    tier = 2,
    class = "fighter",
    sprite = "assets/chars/kobold_broodkeeper.png",
    archetype = "defensive",
    guards = "character_dragon_egg",
    guardRadius = 1,
    stats = {
        health = 46, mana = 0, stamina = 18,
        staminaRegen = 2,
        damage = 10, magicDamage = 0,
        defense = 4, magicDefense = 4,
        movement = 4, -- 5 after the race; the Oath's plate takes one back
        speed = 4,    -- 5 after the race
        skill = 5, luck = 4,
    },
    startingItems = {
        "weapon_iron_spear", "armor_wardens_oath", false,
        false,               false,                false,
        false,               false,                false,
    },
    drops = { "ability_dragon_egg" },
    defaultAction = "weapon_iron_spear",
    signatureWeapon = "weapon_iron_spear",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
