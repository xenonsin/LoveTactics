-- The closer's order. A flat damage course, plus a skill that only pays on a body already down past
-- half (data/traits/trait_meal_finish_the_plate.lua).
--
-- What it is really buying is TURNS. A fallen body in this game does not simply die -- it lies there
-- counting down, revivable, and everything it would have done in the meantime is a turn your line does
-- not have to answer (docs/downed.md). Closing that a swing earlier, four bodies over, four fights in a
-- run, is a great deal more than the +5 looks like written down.
--
-- The obvious comparison is the Macchiato, which is a third of the price for the same +2 and no
-- condition at all. The difference is where the number lands: the coffee helps you open an exchange,
-- and this helps you end one. A company that keeps losing fights it was winning wants this one.
return {
    name = "The Carver's Plate",
    description = "The company strikes harder, and harder still at anything already wounded.",
    flavor = "Carved thin at the counter while you watch, because she trusts nobody else to know when to stop.",
    price = 150,
    unlockPrestige = 4,
    bonus = { damage = 2 },
    skill = "trait_meal_finish_the_plate",
}
