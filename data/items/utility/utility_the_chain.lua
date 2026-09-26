-- THE CHAIN: the War Ogre's organ (approved as pitched, 2026-09-26, "The Orcs of Wrath"). While its Handler lives
-- it stays within 3 and attacks what the Handler strikes; with the Handler dead it is Unchained and attacks the
-- nearest body, either side (trait_the_chain, models/rampage.lua).
return {
    name = "The Chain",
    description = "Stays within 3 of its Handler and attacks what the Handler strikes. With the Handler dead, it is Unchained.",
    flavor = "The chain is not strong enough to hold it. The chain is only strong enough to remind it.",
    sprite = "assets/items/utility_the_chain.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_chain" },
}
