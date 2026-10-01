-- THE RIDDLE: the Sphinx's own (data/characters/character_sphinx.lua; "Pride's Bestiary", 2026-09-30). It
-- carries the rule the fight is about (trait_the_riddle): a riddle each turn, dealt off the fight's seed;
-- unanswered, the Sphinx takes no damage; met, it can be hurt until its next turn ends; failed, it heals 10%.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. The riddle the
-- player CAN carry is the Sphinx's Riddle on its `drops` list, which asks without warding.
return {
    name = "The Riddle",
    description = "Asks a riddle each turn. Unanswered, takes no damage; met, can be hurt until its next turn; failed, heals 10%.",
    flavor = "It is never wrong. It would like you to know that it has been asking this for a very long time.",
    sprite = "assets/items/utility_the_riddle.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_the_riddle" },
}
