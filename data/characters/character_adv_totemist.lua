-- TOTEMIST, as an adventurer ("The Rift's Adventurers", 2026-10-09; models/adventurers.lua). A race-free
-- body fielded as `character_adv_totemist@<race>`; `race` names the first leaning race only so the
-- blueprint loads. Built on the generic archer (the hunter root the exemplar walks): 15 / 3 magic.
--
-- WHAT IT DOES ON THE BOARD (The Long Invocation, The Summoning): it plants a totem whose ground heals the
-- party (Raise Totem, once, on twelve of fifteen mana) and Carved Stakes whose ground hands every ally in
-- it a barrier that swallows a blow. The stake needs a bow beside it in the grid, which is why the bow
-- sits in cell 1. Both zones lift when their totem is cut down -- the page's counter, break the totem.
--
-- NOT BUILT: the page's totem also "cancels spells cast into its field". No item on the totemist's,
-- priest's or hunter's shelves does that (the stake's barrier is physical), so the body carries the
-- nearest thing that exists rather than an item coined for it.
return {
    name = "Totemist",
    race = "orc",
    tier = 2,
    adventurer = true,
    sprite = "assets/chars/totemist.png",
    class = "hunter",
    discipline = "totemist",
    archetype = "support",
    stats = {
        health = 52, mana = 15, stamina = 23,
        staminaRegen = 2,
        damage = 14, magicDamage = 3,
        defense = 5, magicDefense = 6,
        movement = 4,
        speed = 4,
        skill = 8, luck = 4,
    },
    startingItems = {
        "weapon_iron_bow", "ability_carved_stake", "ability_raise_totem",
    },
    defaultAction = "weapon_iron_bow",
    signatureWeapon  = "weapon_iron_bow",
    signatureAbility = "ability_raise_totem",
    -- 1. The healing totem once somebody is hurt. 2. A stake over the line as the foe closes.
    -- 3. Shoot the wounded.
    ai = {
        { priority = "urgent", act = "support", item = "ability_raise_totem", targetPref = "most_wounded",
          when = { subject = "any_ally", test = "hp_pct_below", value = 0.7 } },
        { priority = "high", act = "support", item = "ability_carved_stake",
          when = { subject = "any_foe", test = "within", value = 5 } },
        { priority = "normal", act = "attack", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
