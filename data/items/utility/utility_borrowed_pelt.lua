-- Mira's bound relic (Druid). A fourth shape, and the only one that is not for sale.
--
-- THE FORMS SHE OWNS ARE THE GATE, NOT THE PRIZE. It banks `shifted` -- a shape she took HERSELF,
-- never one she inflicted on somebody else (the split is drawn at fx.transform) -- so Wild Shape:
-- Bear, Wolf and Raven are what open it. Two changes this fight, and the pelt is worth wearing.
--
-- WHY A WYRM AND NOT A GRYPHON, since it was the design question. The three shelf shapes already own
-- three axes: the Raven owns flight and reach, the Bear owns bulk, the Wolf owns pace. A flying mythic
-- would have been a better raven -- a straight upgrade to a form she already has, which is the second-
-- copy failure. Burrowing is the axis none of them touch. See data/characters/character_wild_wyrm.lua,
-- and Old Breath in particular: the form's third attack takes the element of the ground she is standing
-- in, so a druid who has been shaping the floor all fight has been loading it without being told.
--
-- UPKEEP works exactly as the three shelf shapes' does: `reserve` rides on the cast rather than on the
-- status, because a self-transform is sustained like a summon and only the cast knows what its own
-- ability declared. fx.transform binds it, the status counts it down, the revert releases the lien.
return {
    name = "The Borrowed Pelt",
    description = "Turns you into a wyrm, gaining Wyrm Shape. Reserves mana while worn.",
    flavor = "Stitched from everything she has been. What it makes was never any of them.",
    sprite = "assets/items/sig_borrowed_pelt.png",
    type = "utility",
    tags = { "signature", "primal", "illusion" },
    class = "hunter",
    discipline = "druid",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        -- No cost beside the reservation, exactly as the shelf shapes have none: a reservation is
        -- already both a price and a lock, and charging on top bills the druid twice for one body.
        reserve = { stat = "mana", percent = 0.3 }, -- held for as long as the shape is worn
        description = "Turns you into a wyrm, which moves through the ground rather than across it.",
        unlock = { event = "shifted", count = 2, text = "Change shape twice" },
        effect = function(fx)
            if fx.transform(fx.user, "character_wild_wyrm") then
                fx.applyStatus(fx.user, "status_wild_shape_wyrm")
            end
        end,
    },
    -- wearing a wyrm is not a subtle item
    bonus = { damage = 2 },
}
