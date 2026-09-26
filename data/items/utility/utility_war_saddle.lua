-- THE WAR SADDLE: what makes a Goblin Wolf-Rider two bodies in one (approved as pitched, 2026-09-26, "The Goblins
-- of Wrath"). The lethal blow kills only half of it (trait_two_in_one): shot from range, the rider falls and the
-- wolf goes wild (Seeing Red); cut down up close, the wolf falls and the rider rolls clear as a Goblin Cutter. So
-- the goblins' own weakness to the bow decides which fight comes after. Bound and unstealable: no drop of its
-- own -- the wolf drops what wolves drop.
return {
    name = "War Saddle",
    description = "The first lethal blow kills only half: from range, the rider falls; up close, the wolf does.",
    flavor = "Nobody agreed to this. Not the goblin, and certainly not the wolf.",
    sprite = "assets/items/utility_war_saddle.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_two_in_one" },
}
