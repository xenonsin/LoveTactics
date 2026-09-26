-- HOLDING THE CHAIN: the orc Beast-Handler's organ (approved as pitched, 2026-09-26, "The Orcs of Wrath"). Its War
-- Ogre attacks whatever it strikes, and its death unchains the ogre (trait_holding_the_chain, trait_the_chain).
return {
    name = "Holding the Chain",
    description = "Its War Ogre attacks whatever it strikes. If it falls, the ogre is Unchained.",
    flavor = "It holds the chain the way you would hold a torch in a powder store.",
    sprite = "assets/items/utility_holding_the_chain.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_holding_the_chain" },
}
