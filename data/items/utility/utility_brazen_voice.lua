-- BRAZEN VOICE: the Brazen Head's own (data/characters/character_brazen_head.lua; "Envy's Bestiary", 2026-10-03,
-- slice C). It keeps the head's three utterances in order and writes down where its side stands each time it
-- speaks (trait_three_utterances), which is what Time Was reads back.
return {
    name = "Brazen Voice",
    description = "Speaks Time Is, Time Was and Time Is Past, in order. Each is a wind-up a shove breaks.",
    flavor = "It was built to answer one question. It has been answering it ever since.",
    sprite = "assets/items/utility_brazen_voice.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    traits = { "trait_three_utterances" },
}
