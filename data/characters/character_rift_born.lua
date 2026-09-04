-- RIFT-BORN: Wrath's apex, a 2x2 body, and a fight that shrinks the room rather than growing itself.
--
-- Each threshold sheds a pair of ember-spits (data/items/utility/utility_riftline.lua), and an
-- ember-spit leaves fire where it falls. So the escalation is not on the Rift-Born's stat line -- it is
-- on the floor, and every one of the little ones you kill takes another square of standing room.
--
-- Which is the right shape for an apex on the `rifts` carve. The volcanic board is open country with one
-- road; there is no warren for a four-tile body to plug, so its denial has to be manufactured. It
-- manufactures it.
--
-- Tier 3's band is 81-154 health.
return {
    name = "Rift-Born",
    kind = "elemental",
    tier = 3,
    sprite = "assets/chars/rift_born.png",
    footprint = { w = 2, h = 2 },
    stats = {
        health = 132, mana = 0, stamina = 24,
        staminaRegen = 2,
        damage = 15, magicDamage = 6,
        defense = 9, magicDefense = 13,
        movement = 3,
        speed = 3,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 4, luck = 6,
    },
    -- INNATE MITIGATION (models/character.lua `resist`), in the same unit an armour's resist
    -- table is written in and summed into the same total. This body wears nothing, so this is
    -- what it has instead of a coat -- and the negative line is not an oversight, it is the
    -- price. See docs/bestiary.md, "What a creature wears instead of armour".
    --   Wrath's apex is a hole with edges, and hitting a hole accomplishes very little.
    --   The edges are what you cut. The cold is what closes it.
    resist = { impact = 4, slash = -4, fire = 4, ice = -8 },
    startingItems = { "weapon_rift_jaws", "utility_riftline" },
    defaultAction = "weapon_rift_jaws",
    archetype = "aggressive",
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
