-- The King Slime's own body (data/characters/character_king_slime.lua), and the same piece as
-- data/items/utility/utility_amorphous_body.lua with one rule added: it comes apart.
--
-- TWO BLUEPRINTS RATHER THAN ONE WITH A FLAG, for the reason weapon_demon_claws was cut out of
-- weapon_great_claws: a shared blueprint splits rather than lies. Bolting `trait_split` onto the
-- common body would hand the rule to every slime in the fen, and the first thing a King does when it
-- falls is make three of those. That is not a content decision, it is an infinite board.
--
-- The immunity is identical, deliberately. A King is not harder to cut than a slime -- it is exactly
-- as impossible, and the difference is entirely how much of it there is and what is inside. A player
-- who learned the rule off the common body is never surprised by the crowned one, which is the
-- promise data/characters/character_demon_bomblet_tutorial.lua makes about its 12 and for the same reason.
return {
    name = "Sovereign Mass",
    description = "Voids blades, points and blows. Takes on elements, compounds each turn, and divides when it falls.",
    flavor = "There was never a king in it. There was only ever more of it.",
    sprite = "assets/items/sovereign_mass.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    -- Split BEFORE Interest: Comes Apart hands the King's account to his pieces and marks it passed,
    -- so his own death pays nothing twice. He banks double what a slime does (trait_interest).
    traits = { "trait_adaptive", "trait_split", "trait_interest" },
    traitParams = { interestStep = 3, interestGold = 8 },
}
