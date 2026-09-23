-- THE ANOINTED: the Abbess's congregation, worn. Not a relic and not a charm -- the people she has
-- already blooded, which in a fight means whoever she is holding at the time.
--
-- A creature's rule lives on an ITEM in its grid: a blueprint's own `traits` field is never collected
-- (models/trait.lua). Two of them here, because they are one object read at two moments --
--
--   The First Yes      she walks on already holding one of you (data/traits/trait_the_first_yes.lua)
--   The Congregation   and a wound meant for her opens in them instead
--
-- ...and the second is worth nothing without the first, which is exactly why they ride together rather
-- than in two cells. A split with nobody to split across is a blank rule, and an opening charm with no
-- payoff is two turns of inconvenience. Put on one item they are a single sentence: **she arrives
-- standing behind one of you, and does not step out from there.**
--
-- SUNDER TAKES BOTH AT ONCE, which is the clean counterplay a single vessel buys: Trait.flag refuses
-- every flagged rule on a body holding `status_sundered`, so silencing her relic is hitting her
-- directly for as long as it holds. Two items would have needed silencing twice.
--
-- The rift sells the second half of this and never the first (data/items/utility/utility_the_congregation.lua):
-- an opening that hands the player a free charm at the bell is a different item in a different game.
--
-- A creature's kit: no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "The Anointed",
    description = "Opens the fight with one foe Charmed, and splits damage dealt to you among the Charmed.",
    flavor = "She keeps the intake rolls the way another woman keeps letters.",
    sprite = "assets/items/the_anointed.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "charm", "dark" },
    noSteal = true,
    traits = { "trait_the_first_yes", "trait_the_congregation" },
}
