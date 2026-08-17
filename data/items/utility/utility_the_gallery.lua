-- THE GALLERY: three suits that fight as one, and the phase script that keeps standing them back up.
--
-- The design promise was "animated armour acting as one body across several suits". The honest version
-- of that inside this engine is a body which, every time it is cut past a threshold, puts another suit
-- of itself on the board -- so killing the Gallery means killing it faster than the hall replaces it,
-- and the rank it stands in is being topped up while you work.
--
-- WHICH IS ALSO THE ONLY VERSION WORTH SHIPPING. A true multi-body single unit -- one health bar across
-- three tiles -- would need real engine surgery in turn order, targeting and death, and the proposal it
-- came from flagged it as the one item likely to. This gets the board-level idea (you cannot finish it
-- by finishing one suit) out of machinery that already exists and is already tested.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "The Gallery",
    description = "Stands another of its suits up as it is wounded.",
    flavor = "The hall was hung with them. It is not obvious which one anybody was ever looking at.",
    sprite = "assets/items/the_gallery.png",
    type = "utility",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_formation_fighter", "trait_close_ranks", "trait_boss_phases" },
    phases = {
        { at = 0.66, responses = {
            { kind = "summon", id = "character_gilded_sworn", count = 1 },
            { kind = "log", text = "Another suit steps down off the wall." },
        } },
        { at = 0.33, responses = {
            { kind = "summon", id = "character_gilded_sworn", count = 1 },
            { kind = "log", text = "And another. The hall has a great many of them." },
        } },
    },
}
