-- Smoke Bomb: a one-use escape carried in the grid. It grants the Smoke Screen trait, whose pre-hit
-- reflex (Trait.trySmoke) negates the first attack that would land on the bearer and blinks it two
-- tiles clear of the attacker -- then the charge is spent for the battle. Not a thrown consumable: the
-- value is the reaction, not an action you choose to take.
return {
    name = "Smoke Bomb",
    description = "The first attack that would hit you is lost in smoke, and you slip two tiles clear. Once per battle.",
    sprite = "assets/items/smoke_bomb.png",
    type = "utility",
    tags = { "smoke" },
    class = "rogue",
    price = 200,
    repRank = 2,
    traits = { "smoke_screen" },
}
