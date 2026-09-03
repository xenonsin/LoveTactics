-- A tallow hound: the Gluttony circle's specialist, and the body that carries Engorge.
--
-- Everything nearby that dies feeds it -- your bodies, and its own flies just as readily
-- (data/traits/trait_engorge.lua). So the pack's combo runs itself: the swarm bleeds your line, the
-- hound finishes what the swarm softened, and clearing the swarm out of the way feeds it too. There is
-- no order of operations that starves it completely, only orders that starve it more.
--
-- The rule rides on the hide in its grid rather than on this blueprint, because a blueprint's own
-- `traits` field is never collected -- only an item's is (models/trait.lua). Same reason each of the
-- seven generals is a relic plus a weapon.
--
-- Its teeth are deliberately plain (data/items/weapon/weapon_tallow_maw.lua). A specialist whose weapon
-- ALSO did something would bury the rule the whole circle is built to teach.
return {
    name = "Tallow Hound",
    kind = "beast",
    tier = 2,
    sprite = "assets/chars/tallow_hound.png",
    stats = {
        health = 54, mana = 0, stamina = 22,
        staminaRegen = 3,
        damage = 14, magicDamage = 0,
        defense = 5, magicDefense = 3,
        movement = 5, -- it has to reach the dying, which is where its rule pays
        speed = 5,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 3, luck = 5,
    },
    startingItems = { "weapon_tallow_maw", "utility_rendered_hide" },
    defaultAction = "weapon_tallow_maw",
    -- Basic tactics (models/ai.lua): finishes what is closest to falling. The AI wanting the kill and
    -- the trait being paid for the kill are the same instinct, which is what makes the body read.
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
