-- Warden's Writ: the knight half of the Warden (knight x hunter), and the item that finally says what
-- this discipline's "zone" actually is. Every hazard the bearer lays down also Halts what walks into it.
--
-- The discipline was drafted around the word "zone" and the word was doing no work -- there is no zone
-- layer in this engine. What there is: hazards (34 items call fx.placeHazard) and incense, ground that
-- walks with you (32 more). So the Warden is defined against hazards, and defined GENERICALLY: this
-- charm names no hazard at all. A warden's fire Halts, a warden's rain Halts, a warden's quicksand
-- Halts, and so will anything authored after this file.
--
-- Halted rather than Rooted deliberately. Root takes movement; Halt takes the turn without touching the
-- body (status_halted), and leaves the victim's reflexes alone so it is not a second Stun. That is the
-- knight's own word -- sloth inflicted rather than suffered -- and it is what makes a warden's line a
-- decision for the enemy rather than a wall: you may still walk in. You will just not do anything else.
--
-- It pairs with Marchstone, which gives a warden ground to lay when it has no spell for it, and with
-- Beat the Bounds, which collects on everyone standing in ground of any kind.
return {
    name = "Warden's Writ",
    description = "Every hazard you place also Halts the foes that enter it.",
    flavor = "The border is wherever she last set something down. It has been moving all week.",
    sprite = "assets/items/utility_wardens_writ.png",
    type = "utility",
    tags = { "charm", "control" },
    class = "knight",
    discipline = "warden",
    price = 420,
    unlockQuests = 6,
    traits = { "trait_wardens_writ" },
}
