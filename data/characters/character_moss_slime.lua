-- THE MOSS SLIME: the fen's slime (data/characters/character_slime.lua) as the wood grows it, and the
-- first place a company meets the question "did you bring an element".
--
-- The fen's body answers steel with nothing at all, and that is right four floors down. It is wrong on
-- the floor a descent opens on, where the company is a pair with a mace and a crozier and every fight
-- must be cleared (Gluttony's gate is `clear`). So this one answers steel with about half
-- (utility_mossy_body): an element lands whole and is taken in. A company without an element wins the
-- long way; the lesson is the same one, priced in turns rather than in a wall.
--
-- AND IT EATS ITS KIN, which is Gluttony's slime rule (data/items/ability/ability_coalesce.lua): a moss
-- slime beside another swallows it and takes its health into itself. Kill them apart.
--
-- Everything else is the fen body's: slow, soft, corrosive, adapting. It is the same animal.
return {
    name = "Moss Slime",
    race = "beast",
    tier = 2,
    sprite = "assets/chars/moss_slime.png",
    stats = {
        health = 40, mana = 0, stamina = 16,
        staminaRegen = 2,
        damage = 11, magicDamage = 0,
        -- Low on both, as the fen body's are: the physical defence is on the relic, not in the stat.
        defense = 1, magicDefense = 2,
        movement = 3,
        speed = 3,
        skill = 3, luck = 2,
    },
    -- The fen body's elemental trade, unchanged: acid is what it is for, cold stops it moving.
    resist = { acid = 3, ice = -3 },
    startingItems = {
        false, "ability_corrosive_touch", "ability_coalesce",
        "weapon_pseudopod", "utility_mossy_body", false,
        false, false,                     false,
    },
    defaultAction = "weapon_pseudopod",
    -- ITS OWN PIECE, and only its own (docs/drops.md): the Mosswrap is the slime's rule worn -- a piece
    -- of the wearer sloughs off when they are hurt, and comes back to them (trait_slough).
    drops = { "armor_mosswrap" },
    -- Walks to its kin (AI.POSTURES.gather), which is what puts Coalesce in reach.
    archetype = "gather",
    ai = {
        { priority = "high", act = "cast", item = "ability_corrosive_touch",
          when = { subject = "nearest_foe", test = "in_reach" } },
    },
}
