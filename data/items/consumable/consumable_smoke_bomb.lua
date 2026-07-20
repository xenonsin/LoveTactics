-- Smoke Bomb: a one-use escape carried in the grid. It grants the Smoke Screen trait, whose pre-hit
-- reflex (Trait.trySmoke) negates the first attack that would land on the bearer and blinks it two
-- tiles clear of the attacker -- then the charge is spent for the battle.
--
-- A consumable that is never THROWN: it declares no activeAbility, because the value is the reaction,
-- not an action you choose to take. It sits on the alchemist's shelf with the other bombs (that is what
-- `type` routes) and it is spent in a battle like they are -- the charge just spends itself, on the
-- blow it answers. Traits are collected off every grid item regardless of type (Trait.collect), so the
-- reflex works exactly as it did as a utility.
--
-- `maxStack = 1` against the consumable default of 9: the charge latches once per bearer per battle
-- (trait `stacks` 0 -> 1), so a second bomb in the same slot would buy nothing. One per grid square,
-- and a second escape costs a second square.
return {
    name = "Smoke Bomb",
    description = "Once per battle, the first attack that would hit you is lost in smoke; you slip two tiles clear.",
    flavor = "The Undercroft does not teach fighting. It teaches leaving.",
    sprite = "assets/items/smoke_bomb.png",
    type = "consumable",
    tags = { "smoke" },
    class = "rogue",
    maxStack = 1,
    price = 200,
    repRank = 2,
    traits = { "trait_smoke_screen" },
}
