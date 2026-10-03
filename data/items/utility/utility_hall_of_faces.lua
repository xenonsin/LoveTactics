-- HALL OF FACES: the Faceless Assassin's drop (data/characters/character_faceless_assassin.lua), after the House
-- of Black and White's hall. Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2).
--
-- Every foe the bearer kills hangs a face in the hall (trait_faces_of_the_slain); the button consumes the newest
-- one still hanging and wears it for 2 turns -- that body's stats and kit, on the bearer's own health pool, under
-- the Stolen Face badge. Unlike Borrowed Face it is not once a fight: it is as many times as the bearer has
-- killed. An empty hall refuses the button. An unstocked trophy on the seat's rung.
return {
    name = "Hall of Faces",
    description = "Each foe you kill is a face. Spend one to become that foe for 2 turns; your health stays yours.",
    flavor = "Every face in it was somebody's last. None of them is the wearer's.",
    sprite = "assets/items/utility_hall_of_faces.png",
    type = "utility",
    tags = { "guile", "illusion" },
    class = "assassin",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_faces_of_the_slain" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        cost = { stat = "stamina", amount = 6 },
        counter = function(unit)
            return require("models.stolen_faces").hallCount(unit)
        end,
        counterGates = true,
        counterLabel = "Faces",
        counterEmpty = "No faces in the hall -- kill a foe first",
        effect = function(fx)
            local SF = require("models.stolen_faces")
            local face, index = SF.hallNewest(fx.user)
            if not face then return end
            if fx.transform(fx.user, nil, { char = face }) then
                local spent = {}
                for k, v in pairs(fx.user.hallSpent or {}) do spent[k] = v end
                spent[index] = true
                fx.bank("hallSpent", spent)
                fx.applyStatus(fx.user, "status_stolen_face", { duration = 10 })
            end
        end,
    },
}
