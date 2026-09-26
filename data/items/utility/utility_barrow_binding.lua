-- THE BARROW BINDING: the rite that keeps a barrow-lord standing, worn as the thing it is.
--
-- The enemy-side twin of Marrowlight (data/items/utility/utility_marrowlight.lua), and the reason this
-- is a separate file rather than the same charm on a skeleton: Marrowlight is `class = "necromancer"`,
-- which is EARNED stock, and a creature may not carry earned stock (docs/bestiary.md -- "a wolf is not
-- a Beastmaster"; tests/bestiary_spec.lua enforces it). So the rule crosses over and the SHELF does
-- not, which is exactly the split that rule exists to make: the Barrow Knight is not carrying the
-- player's item, it is the thing the player's item is an imitation of.
--
-- ONE TRAIT AND ONE NUMBER. It grants data/traits/trait_bone_knit.lua unchanged -- the same rule,
-- through the same engine seam, so what the player watches the Barrow Knight do is precisely what the
-- charm will do for them later -- and names its own toll through `traitParams`, which is the whole
-- reason Trait.param exists. Thirty rather than forty, because this body's pool is authored on its
-- sheet and a toll it cannot pay twice is a rule the player never gets to see work.
--
-- IT IS THE LESSON, AND THAT IS ITS JOB. The rift hands over an aspect that makes a body stand back up
-- for mana; a player who has already fought a thing that does it knows what they are being handed. So
-- the teaching body comes FIRST, deeper than the chaff but shallower than the charm, and it teaches by
-- being annoying in the specific way the charm is good: you kill it, it gets up whole, and you work out
-- that the bar you actually have to empty is the blue one.
--
-- Grave-Cold and Bare Bones ride their own files beside this one on the body's grid, rather than being
-- folded in here. One rule per item is the convention every innate in this folder keeps, and it is what
-- lets the rest of the orchard be cold, and be bone, without being unkillable.
return {
    name = "Barrow Binding",
    description = "Consume 30 mana when a blow would fell this body, and it stands back up at full health.",
    flavor = "Nine knots, and eight of them are for show. They never could agree which.",
    sprite = "assets/items/barrow_binding.png",
    type = "utility",
    class = "creature",
    tags = { "dark" },
    noSteal = true, -- it is what holds the body together, not equipment
    -- IT IS ALSO THE BEARER'S PICTURE, and it carries Bare Bones' own immunity rather than riding beside
    -- it, so a Barrow Lord holds exactly ONE skin item. Character.spriteOf takes the first skin it finds
    -- in grid order, and a body wearing two treatments would be a body whose appearance depended on
    -- which cell somebody dropped a charm into -- the kind of thing that works for a year and then
    -- silently stops. `crowned` is the bone skin with a crown struck over it (tools/char_compose.lua's
    -- SKIN): the Lord is a dead knight in a room of dead knights, and his whole fight is that a player
    -- can tell which one he is.
    statusImmunity = { "status_bleed" },
    -- The Lord's lattice (see utility_bare_bones.lua): the tier-3 line his blueprint used to declare
    -- innate, carried by the one piece on his grid that is his bone.
    resist = { slash = 4, pierce = 4, impact = -8, holy = -8 },
    wearerSkin = "crowned",
    traits = { "trait_bone_knit" },
    traitParams = {
        cost = { stat = "mana", amount = 30 },
    },
}
