-- BORROWED FACE: the Faceless line soldier's drop (data/characters/character_faceless.lua), the race's trick lent
-- to a person. Reviewed 2026-10-01..03 ("Envy's Bestiary"); round 1 moved it onto the ninja's shelf.
--
-- The bearer banks the face of each foe it kills (trait_faces_of_the_slain); once a fight it puts on the LAST one
-- for 3 turns -- that body's stats and kit in place of its own, on its own health pool (the transform rule), and
-- the Stolen Face badge owns taking it off. Nothing killed yet, nothing to wear: the button is refused rather
-- than wasted. An unstocked trophy on the seat's rung.
return {
    name = "Borrowed Face",
    description = "Once a fight, become the last foe you killed for 3 turns: its stats and kit replace yours. Your health stays yours.",
    flavor = "It fits better than it should. That is the part to worry about.",
    sprite = "assets/items/ability_borrowed_face.png",
    type = "ability",
    tags = { "guile", "illusion", "utility" },
    class = "ninja",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_faces_of_the_slain" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        cooldown = 9999, -- "once a fight", as every per-battle cast in the tree says it
        cost = { stat = "stamina", amount = 6 },
        counter = function(unit)
            return require("models.stolen_faces").lastSlain(unit) and 1 or 0
        end,
        counterGates = true,
        counterLabel = "Faces",
        counterEmpty = "Nothing killed yet -- there is no face to wear",
        effect = function(fx)
            local face = fx.user and require("models.stolen_faces").lastSlain(fx.user)
            if not face then return end
            if fx.transform(fx.user, nil, { char = face }) then
                fx.applyStatus(fx.user, "status_stolen_face", { duration = 15 })
            end
        end,
    },
}
