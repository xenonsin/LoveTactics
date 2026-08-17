-- The wyrm a druid wears -- the fourth Wild Shape, and the only one that is not on the shelf. It comes
-- with Mira's bound relic (data/items/utility/utility_borrowed_pelt.lua) and nowhere else, which is what
-- makes a signature out of a form: the other three can be bought, this one is who she is.
--
-- WHY A WYRM AND NOT A GRYPHON, recorded because it was the design question and the answer is not
-- obvious. The three shelf shapes already own three axes: the Raven owns flight and reach, the Bear
-- owns bulk, the Wolf owns pace. A flying mythic would have been a better raven -- a straight upgrade
-- to a form she already has, which is the "second copy" failure. Burrowing is the one axis none of the
-- three touch, so this body moves THROUGH the ground rather than across it: Tunnel ignores whatever is
-- standing between, and Underbite arrives from beneath.
--
-- And it ties to her shelf rather than merely being bigger than it. Old Breath takes the element of
-- whatever ground the wyrm is standing in (data/items/ability/ability_old_breath.lua), so a druid who
-- has been laying hazards all fight has been loading this form's third attack without knowing it.
--
-- Built to the bear's durability rather than the raven's -- a body that closes by surfacing under you
-- has to survive arriving. See data/characters/character_wild_raven.lua for the shape this follows.
return {
    name = "Wyrm",
    kind = "beast",
    tier = 3,
    sprite = "assets/chars/wyrm.png",
    -- Tier 3's band is 81-154 health (docs/bestiary.md, pinned by tests/bestiary_spec.lua). It sits at
    -- the bottom of that band rather than the middle: this is a shape a druid wears, so it should be
    -- the sturdiest of her four and still nothing like the tier-3 bodies she FIGHTS.
    stats = {
        health = 88, mana = 0, stamina = 26,
        damage = 17, magicDamage = 8, -- the breath is the one magical thing a Wild Shape does
        defense = 6, magicDefense = 5,
        movement = 4, -- on the surface. Tunnel is how it actually crosses ground
        speed = 4,
    },
    startingItems = { "weapon_underbite", "ability_tunnel", "ability_old_breath" },
    defaultAction = "weapon_underbite",
    -- Basic tactics (models/ai.lua), for when something else is driving this body -- a charmed druid,
    -- a copy. It surfaces on whatever is already hurt, which is the same instinct the shape is for.
    ai = {
        { priority = "high", act = "attack", item = "weapon_underbite", targetPref = "lowest_hp",
          when = { subject = "any_foe", test = "in_reach" } },
    },
}
