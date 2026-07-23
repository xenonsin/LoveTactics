-- Slot 5 of the Cathedral's ten: THE DISCOVERY, and the line's casualty-list-read-as-an-honor-roll.
--
-- Every line has this room and every one of them plays the same trick with its paperwork (docs/story.md
-- -- the Bastion's martyrs, the Arcanum's donor roll, the Lodge's named trophies, the Bank's settled
-- accounts). The Cathedral's version is the intake register: every child received, and beside the ones
-- the blooding killed, the words ASCENDED TO THE LIGHT. It is read aloud at feasts. It is the roll of
-- the church's glorious dead and there is not one saint on it.
--
-- The quest sets the register against the thing it describes: the unmarked pit behind the almshouse
-- where the bodies were carted. Nothing is hidden here -- the register is public, the pit is not
-- guarded because nobody has ever thought to connect them, and the player is the one who walks the
-- distance between the two.
--
-- What it costs Amana: she can read the register. She was taught to, in that building, as an acolyte.
-- She finds the year she was taken and counts the ascended in it.
--
-- `reach` (region "far"): get to the register room. The Cathedral's guard is between you and it, and a
-- player who runs the corridor rather than clearing it has understood the assignment -- the point of
-- the slot is the page, never the bodies in the way.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. This slot owes the line an UNBUYABLE --
-- story.md budgets one here, the intake register itself, a grid bonus scaling with adjacent allies (à
-- la the Greywatch Muster Roll), `class = "priest"`, no `price` -- and it is not written yet, so no
-- `rewardItems` entry points at it.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Roll of the Given",
    description = "The Cathedral reads its glorious dead aloud at feasts. Reach the register, and " ..
        "read it beside the pit behind the almshouse.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardItems = { "weapon_censer_of_the_hollow_dark", "armor_reliquary_mantle" },
    rewardGold = 220,
    rewardRep = 45,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "cathedral", rank = 2 }, -- Acolyte
    map = {
        biome = "castle",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Register Room",
            composition = function(ctx)
                local list = { "character_priest" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_knight" end
                return list
            end,
            win = { type = "reach", region = "far" },
        },
        keyCount = 2,
    },
}
