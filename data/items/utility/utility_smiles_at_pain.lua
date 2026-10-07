-- SMILES AT YOUR PAIN: the Wasting One's own (data/characters/character_wasting_one.lua; "Envy's Bestiary", round
-- 4). It carries the Thin Smile (trait_the_thin_smile): every wound a foe takes in its sight heals it by 2.
--
-- `bound`, `noSteal`, `class = "creature"`: a creature's organ is never handed to the player. What the fight hands
-- over is on the body's `drops` list instead (The Thin Smile).
return {
    name = "Smiles at Your Pain",
    description = "Heals 2 whenever a foe it can see takes a wound.",
    flavor = "She never smiles, except when she sees another suffer.",
    sprite = "assets/items/utility_smiles_at_pain.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_the_thin_smile" },
}
