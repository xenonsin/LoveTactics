-- Slot 4 of the Arcanum's ten: the escalation, and the first look at the practice itself rather than
-- its results.
--
-- The Adepts of the inner circle are met MID-EXPERIMENT, and the staging matters: nobody is hiding,
-- the doors are not locked, the work is logged, and the two of them are irritated at the interruption
-- the way a surgeon is irritated. Necromancy and blood magic, in the light, in a building the crown
-- funds (docs/story.md, "The Arcanum, and what it is allowed to do"). The horror is procedural. There
-- is a requisition form for the subjects.
--
-- Why it is a fight: they will not stop, and they are entirely willing to spend the room to avoid
-- losing the batch. The dead in here are the Arcanum's own material and they get up when told to,
-- which is the first time the player sees the second-form mechanic the finale is built on.
--
-- What it costs Gyeom: these are people she trained beside. One of them asks her, without cruelty,
-- what she has produced lately -- and she has no answer that this house would count, because slow
-- daily work does not produce anything you can put on a table. She does not correct him. Sublimitas
-- will make the same measurement at slot 7 and be equally wrong, and the player should already have
-- seen Gyeom decline to argue once.
--
-- `killAll`: a working chamber with everything in it animate, and no mark worth cutting out -- the
-- Adepts are interchangeable, which is itself the point.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own
-- unbuyable is still unwritten. The Adepts
-- want bespoke blueprints; `character_mage` and `character_priest` stand in, with `character_zombie`
-- and `character_gaunt_vigil` as the material.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Inner Circle",
    description = "Two of the Arcanum's Adepts, met in the middle of the work. The doors are not " ..
        "locked, the log is up to date, and they are annoyed that you knocked.",
    difficulty = "Normal",
    sponsor = "arcanum",
    rewardItems = { "weapon_graven_circle_staff", "armor_gaunt_vigil_plate" },
    rewardGold = 180,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "arcanum", rank = 2 }, -- Adept
    map = {
        biome = "castle",
        encounters = { min = 6, max = 8, always = { "encounter_elite" } },
        objective = {
            name = "The Working Chamber",
            composition = function(ctx)
                local list = { "character_mage", "character_priest" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_zombie" end
                list[#list + 1] = "character_gaunt_vigil"
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
