-- The attrition order: defense and a raised ceiling to soak into, plus the skill that pays when the
-- run has already gone wrong (data/traits/trait_meal_the_wake.lua).
--
-- It is deliberately the platter that is WORTH MORE ON A BAD DAY. Every other order on this menu is
-- best when it is working; The Wake is a course you only ever collect after somebody has gone down, so
-- a company that clears the quest untouched has overpaid and a company that limps to the objective with
-- two standing has bought the fight back. That asymmetry is the point of having it on a menu rather
-- than on a shelf -- you order it when you look at the board and think *this one is going to hurt*.
return {
    name = "The Cold Board",
    description = "Hardens the company, and steadies whoever is left each time an ally falls.",
    flavor = "Cold meats, hard cheese, black bread. Nothing on it needs a fire, and nothing on it spoils.",
    price = 150,
    unlockPrestige = 5,
    bonus = { defense = 2 },
    maxBonus = { health = 12 },
    skill = "trait_meal_the_wake",
}
