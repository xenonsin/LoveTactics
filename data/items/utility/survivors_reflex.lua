-- The bandolier that carries the Survivor's Reflex (data/traits/survivors_reflex.lua): a bloodied
-- wearer drinks a healing potion out of their own grid without spending the turn to do it.
--
-- Dead weight without flasks to draw on, which is the build it asks for: pair it with the potions it
-- drinks and it is a second health bar, carry it alone and it is a strap. The alchemist's shelf sells
-- both halves, and neither half is worth much without the other.
return {
    name = "Alchemist's Bandolier",
    description = "Bloodied by a blow, you drink a healing potion on reflex -- no turn spent. Bring flasks.",
    sprite = "assets/items/survivors_reflex.png",
    type = "utility",
    tags = { "satchel" },
    class = "alchemist",
    price = 260,
    repRank = 2,
    traits = { "survivors_reflex" },
}
