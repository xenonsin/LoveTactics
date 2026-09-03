-- The raven a druid wears (data/items/ability/ability_wild_shape_raven.lua) -- not a summon and not an
-- enemy, but a BODY: Wild Shape swaps the hunter into this blueprint and hands them its kit
-- (models/transform.lua), so what this file lists is what the shifted hunter can do.
--
-- Built as the opposite trade to the wolf and the bear, which both cost you your reach to buy you a
-- body. This one keeps the reach: Flung Quills throws at two or three tiles, and the Fan of Feathers
-- covers the dead zone underneath it. What it pays instead is DURABILITY -- the thinnest health and
-- armour of the three shapes, on the fastest legs. A raven that is being hit is a raven that has already
-- made a mistake.
--
-- See data/characters/character_wolf_grunt.lua for the shape this follows, and character_hawk.lua for
-- the deliberately different bird: that one is the Beastmaster's spotter, summoned by the Falconer's
-- Glove and armed only with Talons. This is a form somebody wears, and it fights at range. Two birds,
-- two shelves, no overlap.
return {
    name = "Raven",
    kind = "beast",
    tier = 1,
    sprite = "assets/chars/raven.png",
    stats = {
        health = 22, mana = 0, stamina = 20,
        damage = 9, magicDamage = 0,
        defense = 2, magicDefense = 3,
        movement = 6, -- wings: it goes where the shot needs to be taken from
        speed = 6,
        -- Accuracy (docs/accuracy.md): skill raises Hit and Crit, luck raises Avoid and blunts an
        -- attacker's crit. Authored, and never grown -- these are what this body IS.
        skill = 2, luck = 5,
    },
    startingItems = { "weapon_flung_quills", "ability_fan_of_feathers" },
    -- Basic tactics (models/ai.lua), for the cases where something else is driving this body (a charmed
    -- druid, a copy): a bird keeps its distance and picks at whatever is closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
