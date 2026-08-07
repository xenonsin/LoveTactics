-- The most expensive thing on the menu, and the last to open. Small courses; the whole price is the
-- kitchen skill (data/traits/trait_second_wind.lua), which refuses one death per member per battle.
--
-- On a board where a fallen body starts a countdown toward being a corpse, and where the loss condition
-- is the company running out of bodies to send in, buying back a death outright is the largest thing
-- gold can do for a run. It is gated at the top of the ladder for that reason rather than because it is
-- a big number -- it is barely a number at all.
--
-- What keeps it from being the only order anybody ever places: it comes up on a SLIVER, not a second
-- life. A member saved by this is standing in whatever just killed them with almost nothing left, and
-- if the turn it bought is not spent getting them out, it bought nothing. See `revivesAt` in the trait.
return {
    name = "The Empty Chair",
    description = "Once per battle, each member survives a lethal blow on a sliver of health.",
    flavor = "Laid for eight and eaten by seven, every year on the same night. You are welcome to the place nobody takes.",
    price = 340,
    unlockPrestige = 8,
    bonus = { defense = 1, magicDefense = 1 },
    skill = "trait_second_wind",
    -- The supper refuses the death but not the recovery: a sliver, where a relic's Second Wind rises at
    -- half. This used to be a trait of its own (Moxie) that was Second Wind with this one number changed
    -- -- it is now the number, named here beside the dish that pays for it (Trait.param).
    skillParams = { revivesAt = 0.15 },
}
