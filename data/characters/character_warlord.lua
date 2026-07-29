-- Enemy boss blueprint (quest objective). See data/characters/bandit.lua.
return {
    name = "The Warlord",
    boss = true, -- a quest objective: immune to execute (Coup de Grace) and to Charm
    sprite = "assets/chars/warlord.png",
    stats = {
        health = 155, mana = 20, stamina = 25,
        damage = 28, magicDamage = 8,
        defense = 16, magicDefense = 10,
        movement = 4,
        speed = 2, -- heavy
    },
    -- The Warlord subclass (fighter): banner zones -- planted banners project stacking aura fields.
    -- Enriched with the banner ACTIVES (Muster/Rally banner, War Drums) so it demonstrates the
    -- discipline; the weapon and its stat line are left exactly as the quest boss was tuned (the aura
    -- charm banners are deliberately NOT added, so nothing passively changes its combat numbers -- see
    -- combat_spec / breakdown_spec, which spar against this body). Kit tag: data/disciplines/warlord.lua.
    startingItems = {
        "weapon_iron_sword",  "ability_muster_banner", "ability_rally_banner",
        "consumable_war_drums", false,                 false,
        false,                false,                   false,
    },
    defaultAction = "weapon_iron_sword",
    -- Basic tactics (models/ai.lua): press the wounded -- finish the foe already closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
