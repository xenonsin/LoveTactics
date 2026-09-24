-- TAWNY HIDE: how the Sabertooth hides, carried as creature kit. It wears the Smoke Mantle's own rule
-- (data/traits/trait_smoke_mantle.lua) -- draw no blood on a turn and you open the next one Invisible, on
-- any tile -- which the review chose over a rule of the cat's own ("one rule, one name, already on the
-- shelf"). The Smoke Mantle itself is ninja armour, and a beast carries natural kit only (docs/bestiary.md:
-- unpriced, noSteal, never a discipline item), so the rule rides this instead and the badge still reads
-- Smoke Mantle.
--
-- NOT TIED TO THE WOOD ("don't need a forest", round two). A Mark shuts it off, exactly as it shuts off a
-- ninja's: status_mark `forbids` Invisible.
return {
    name = "Tawny Hide",
    description = "Draw no blood on a turn and you open the next one Invisible.",
    flavor = "Lying down in the open, it is a patch of dry grass. The patch is looking at you.",
    sprite = "assets/items/utility_tawny_hide.png",
    type = "utility",
    class = "creature",
    tags = { "beast", "illusion" },
    noSteal = true,
    traits = { "trait_smoke_mantle" },
}
