-- GOLD, AS A THING YOU HOLD (2026-11-24). One stack in the stash -- one slot however much of it there
-- is -- and `player.gold` is a view onto it (models/player.lua's Player.bindGold).
--
-- NONE OF IT GOES DOWN THE STAIR. Underground the view points at the bag instead, which starts every
-- run empty: what a company spends down there (a road merchant, an altar, a Mammonite's coin) is what
-- it found down there. A wipe loses it with the rest of the bag (Descent.wipe); the hoist and the Rift
-- Mule can send it up like any find; climbing out lands it on the shelf (Player.unpack).
--
-- A material only so the containers, the save and the wipe carry it with no branch of their own.
-- `currency` keeps it out of everything that counts or lists forging stock (Material.isCurrency).
return {
    name = "Gold",
    description = "Coin. Spent in town and on the road. None of it goes down the stair.",
    sprite = "assets/materials/gold.png",
    currency = true,
}
