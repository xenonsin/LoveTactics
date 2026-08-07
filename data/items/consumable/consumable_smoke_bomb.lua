-- Smoke Bomb: an escape carried in the grid. It grants the Smoke Screen trait, whose pre-hit reflex
-- (Trait.trySmoke) negates an attack that would land on the bearer and blinks it two tiles clear of
-- the attacker -- burning one bomb off the stack each time it answers.
--
-- A consumable that is never THROWN: it declares no activeAbility, because the value is the reaction,
-- not an action you choose to take. It sits on the alchemist's shelf with the other bombs (that is what
-- `type` routes) and it is spent in a battle like they are -- the charge just spends itself, on the
-- blow it answers. Traits are collected off every grid item regardless of type (Trait.collect), so the
-- reflex works exactly as it did as a utility.
--
-- It stacks to the consumable default of 9, and the STACK is the charge count: how many blows you can walk
-- out of is how many bombs you bought, not a per-battle latch. That keeps the escape a supply question
-- (restock between fights, or ration them) rather than a free reflex the grid square grants forever --
-- which is the line between this and armor_smokecloth_wrap, the woven once-per-battle version.
return {
    name = "Smoke Bomb",
    description = "The next attack that would hit you is lost in smoke; you slip two tiles clear. One bomb per escape.",
    flavor = "The Undercroft does not teach fighting. It teaches leaving.",
    sprite = "assets/items/smoke_bomb.png",
    type = "consumable",
    tags = { "smoke" },
    class = "rogue",
    price = 130,
    unlockQuests = 4,
    traits = { "trait_smoke_screen" },
}
