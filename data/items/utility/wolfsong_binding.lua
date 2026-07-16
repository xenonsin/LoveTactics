-- The Wolfsong Binding: what holds the Wolfsong Spirit to the archer who called it, and the only
-- thing the great wolf costs her. A passive utility whose whole effect is the trait it grants
-- (data/traits/blood_price.lua) -- when the Spirit falls, its summoner loses half the health she has
-- left. It sits in the Spirit's loadout beside its Fangs the way Feral Instinct sits in a wolf's
-- (data/items/utility/feral_instinct.lua): innate, not bought.
--
-- The price rides on the CREATURE rather than on the horn that called it because the creature is what
-- knows it died -- and a trait reaches a unit only through its grid (models/trait.lua), so a body with
-- no relic to carry the rule cannot be bound at all. See data/items/utility/sig_wolfsong_horn.lua for
-- the bargain this is one half of.
--
-- No `class`/`price`: it is not forged or sold, it is what a conjured thing is made of. `noSteal`
-- matters -- a rogue who could pickpocket the binding would take the Spirit's whole cost off the
-- board and leave the archer a free monster.
return {
    name = "Wolfsong Binding",
    description = "The tie between spirit and summoner: when it falls, its summoner loses half their remaining health.",
    sprite = "assets/items/wolfsong_binding.png",
    type = "utility",
    tags = { "beast" },
    noSteal = true,
    traits = { "blood_price" },
}
