-- A conjured creature, reached only through the alchemist's Summon Golem ability
-- (data/items/ability/ability_summon_golem.lua), which scales it by the item's upgrade level. Final
-- Fantasy Tactics' Golem, which stood in front of the party and let the damage happen to it instead.
--
-- The Crucible's other construct is the Homunculus (data/characters/character_homunculus.lua): frail,
-- cheap, and worth summoning because of what its Poison leaves behind after it falls. This is the
-- opposite end of the same workshop -- the thing you summon because you need something to still be
-- standing in four turns. Between them the shelf has both halves of "a body that is not yours":
-- one that is expendable and one that is immovable.
--
-- Read the stat line as a wall and not a fighter, because that is what it is. It has the most health
-- and the most armor of anything summonable, and a damage stat below the Homunculus's -- it is not
-- meant to win an exchange, it is meant to be in the way of one (see data/traits/trait_bulwark.lua).
-- Movement 2 and speed 1 are the price: it arrives where you put it and it does not meaningfully
-- relocate, so a golem summoned into the wrong lane is a golem you paid full price to watch.
--
-- Its guard is a BLUEPRINT trait rather than an item's, which Trait.attach reads directly
-- (models/trait.lua) -- the guard is what the thing IS, not something it is carrying, so there is
-- nothing to disarm it of and nothing to steal.
return {
    name = "Crucible Golem",
    sprite = "assets/chars/crucible_golem.png",
    stats = {
        health = 55, mana = 0, stamina = 15,
        staminaRegen = 2,
        damage = 4, magicDamage = 0, -- below even the Homunculus: it is a wall, not a fist
        defense = 14, magicDefense = 8,
        movement = 2, -- it arrives where you put it and does not meaningfully relocate
        speed = 1,
    },
    -- Its hands carry its guard (data/items/weapon/weapon_golem_fists.lua). A trait CANNOT be declared
    -- on a character blueprint: Trait.attach reads `unit.char.traits`, but Character.instantiate builds
    -- the runtime character field by field and never copies that field, so declaring it here would be
    -- dead data. Traits reach a unit from grid items and from nowhere else.
    startingItems = { "weapon_golem_fists" },
    -- Basic tactics (models/ai.lua): a wall does not chase. It presses whatever is already in front of
    -- it, so it holds the lane it was summoned into rather than wandering out of guard range of the
    -- allies it was put there to cover.
    ai = {
        { priority = "high", act = "attack", targetPref = "nearest",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
