-- THE UNFINISHED TOWER: the Tower-Giant's own (data/characters/character_tower_giant.lua; "Pride's
-- Bestiary", 2026-09-30). It carries both halves of the rule the fight is about: Ambition, a stack at the end
-- of every one of its turns (trait_ambition), and the Proud Fall, which crashes on everything within
-- 1 + Ambition/3 tiles for 6 damage a stack when it falls (trait_the_proud_fall).
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. The Ambition the
-- player CAN carry is the Babel Maul on its `drops` list, whose next hit consumes the count instead.
return {
    name = "The Unfinished Tower",
    description = "Gains Ambition each turn. When it falls, it crashes within 1 + Ambition/3 tiles for 6 damage per stack.",
    flavor = "It was going to reach heaven. It still means to, one more course at a time, for as long as you let it.",
    sprite = "assets/items/utility_the_unfinished_tower.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_ambition", "trait_the_proud_fall" },
}
