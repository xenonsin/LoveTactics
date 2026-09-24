-- The huntress's phase piece: the script of the first half of her fight, carried in her grid the way
-- every boss carries its phases (a relic authored as data, read by a trait).
--
--   * The Knock (trait_the_knock) -- hit her hard enough and what she ate comes back out of her.
--   * The Turning Hunger (trait_turning_hunger) -- at half health she becomes the beast, and keeps what
--     she was holding when she turned.
--
-- Both are hers and neither is the Maw's. The Maw is what she drops; this is what she IS until she turns,
-- and it goes with the woman's grid when the beast's replaces it -- which is exactly when both rules
-- should stop.
return {
    name = "The Turning Hunger",
    description = "A hard enough hit knocks her copied power out. At half health, she turns into the beast.",
    flavor = "Every Grand Hunter turns. Most of them turn into a mere animal.",
    sprite = "assets/items/the_turning_hunger.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_the_knock", "trait_turning_hunger" },
}
