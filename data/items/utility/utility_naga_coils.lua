-- A naga's own coils: the length of it below the belt, and the reason it belongs in the water.
--
-- NOT KIT. It is an ORGAN, and it sits in the grid for one reason -- Combat.isAquatic scans the grid
-- for the `swim` tag, and the grid is the character sheet. A player who looks at a Shoalkin and wonders
-- why it is standing in a channel gets the answer on the same surface that answers everything else
-- about it, rather than from a field nothing draws.
--
-- GRANTED BY THE RACE, never authored into a blueprint (data/races/naga.lua's `grants`).
-- Character.instantiate seeds it into the first free cell of every naga that is ever minted, which is
-- what makes the race do real work: four blueprints do not each have to remember to carry their own
-- legs, and the fifth naga somebody writes cannot forget.
--
-- BOUND AND UNSTEALABLE, which is the honest split between an organ and a piece of kit. Swimming never
-- comes off a naga's corpse; what the player takes off the Undertow is the Gillscale Wrap, a thing
-- somebody MADE out of scale, at a depth and a rarity a made thing can be priced at. A creature's body
-- is not a shelf item -- docs/bestiary.md's oldest rule, and the one the drop pool refuses on directly.
--
-- IT COSTS A GRID CELL, and that is deliberate rather than regrettable. A racial rule with no price is
-- the flying tag's mistake made twice; the demons have paid this same cell for their own crown since
-- long before the race axis existed.
return {
    name = "Coils",
    description = "Water costs one tile to cross and deep water can be entered. You cannot drown.",
    flavor = "It does not end where a man's legs would. It goes on, and then it goes into the water.",
    sprite = "assets/items/naga_coils.png",
    type = "utility",
    tags = { "natural", "swim" },
    class = "creature",
    noSteal = true,
    bound = true,
    -- A NAGA IS NEVER WET, and this is a fix as much as it is flavour.
    --
    -- The flavour first: "soaked" is a thing that happens to a body that is not made for water. A naga
    -- wading the ford is a naga at home, and the ford stands a hazard_shallows on every tile of itself.
    --
    -- The fix is the half worth reading twice. Wet carries `lightning = 6` (data/status/status_wet.lua)
    -- and the naga race carries `lightning = -4` (data/races/naga.lua) -- so without this line, a pack
    -- standing in its own channel would take TEN extra damage from a bolt, and the Tidecaller's own
    -- Stormwake would kill its own side faster than the company's. The faction's whole plan is to fight
    -- in water; a plan that is suicide is not a plan.
    --
    -- The player's counter is untouched, which is what keeps this from being a wall: the race's -4 is
    -- still there, a fen board still conducts, and a bolt through a channel still finds every naga in
    -- it. What the immunity removes is only the compounding, and only on the bodies that live there.
    --
    -- `statusImmunity` is the existing seam (Status.isImmune reads it off any grid item), so this needs
    -- no engine change and it is named in the refusal line the player sees.
    statusImmunity = { "status_wet" },
}
