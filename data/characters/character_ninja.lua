-- Ninja exemplar (rogue x mage multiclass). Dedicated body so the discipline reads as itself on the
-- board -- distinct from Kaen (character_kaen), who stays the marquee boss of the unlock quest while this
-- is the plain discipline stand-in the draft and stray encounters field. Met as a BOSS: a shape that
-- keeps not being where you strike. Home shelf is rogue; the mage half is the illusion-work (clones,
-- misdirection, vanishing -- not the elements). Kit from data/disciplines/ninja.lua. Signature mechanic:
-- Shadowclone -- blink between decoys, vanish from sight, strike from stealth. No VN portrait (a template,
-- not a companion) -- it falls back to its composed token.
return {
    name = "Ninja",
    kind = "humanoid",
    tier = 3,
    sprite = "assets/chars/ninja.png",
    boss = true, -- a boss objective: immune to execute (Coup de Grace) and to Charm
    class = "rogue",
    discipline = "ninja",
    -- Scatters clones, stays unseen, strikes and swaps out (models/ai.lua `skirmish`).
    archetype = "skirmish",
    stats = {
        health = 92, mana = 38, stamina = 22,
        staminaRegen = 2,
        damage = 19, magicDamage = 10,
        defense = 8, magicDefense = 9,
        movement = 4,
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 8, luck = 7,
    },
    -- The 3x3 loadout grid (row-major); false = an empty cell. Vanishing Strike is the build-around --
    -- strike, blink away, vanish -- with Mirror Image and Scatterlight seeding the decoys, Shadow Trade and
    -- Substitution trading places with them, and the Smoke Mantle turning stealth back on at turn start.
    startingItems = {
        "weapon_iron_dagger",   "ability_vanishing_strike", "ability_mirror_image",
        "ability_scatterlight", "ability_shadow_trade",     "utility_substitution",
        "armor_smoke_mantle",   "consumable_healing_potion", "utility_fourth_shadow",
    },
    defaultAction = "weapon_iron_dagger",
    -- Strike the wounded from stealth, then vanish on the same blow.
    ai = {
        { priority = "urgent", act = "attack", item = "ability_vanishing_strike", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
