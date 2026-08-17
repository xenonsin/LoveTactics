-- A cinder-kin: the Wrath circle's line body.
--
-- It burns what it hits and it burns the tile it dies on (data/traits/trait_cinderfall.lua), which is
-- the stratum's rule stated at the rung a fight is actually made of. Where you kill it matters -- kill
-- it in a doorway and the doorway is gone.
--
-- No rule of its own beyond that, deliberately. The circle's interesting bodies are the Forge-Wretch and
-- the Anvil, and a line body that also escalated would make the escalation impossible to attribute.
return {
    name = "Cinder-Kin",
    kind = "demon",
    tier = 2,
    sprite = "assets/chars/cinder_kin.png",
    stats = {
        health = 56, mana = 0, stamina = 20,
        staminaRegen = 2,
        damage = 13, magicDamage = 0,
        defense = 6, magicDefense = 7,
        movement = 4,
        speed = 4,
    },
    startingItems = { "weapon_cinder_brand", "utility_ember_husk" },
    defaultAction = "weapon_cinder_brand",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
