-- Slot 3 of the Hunter's Lodge's ten (docs/story.md, "The Hunter's Lodge: gluttony, designed"): the
-- complication, and it goes wrong in GLUTTONY's specific way rather than a generic one.
--
-- Kaya has agreed to guide, and guiding means camping. This is the first night out, deep enough in
-- that the Lodge's blazes have run out, and the wood does not attack because it is savage. It attacks
-- because it is STARVING. Gula has been killing her way through the deep wood for the pleasure of it
-- and wasting nearly all of it (story.md, "Gula, the cursed hunter") -- the thrill is the point, never
-- the meat -- and everything downstream of that has been pushed out of its range and has not eaten in
-- weeks. The animals coming at the fire are not monsters. They are the second-order effect of one
-- appetite, and they are thin.
--
-- What it costs Kaya: nothing yet, but she is the one who says the wood is wrong, and she says it the
-- way someone says a house is on fire -- flatly, and while already moving. She does not know what is
-- doing it. She knows the shape of what it leaves.
--
-- `hold` rather than `survive` (the recruit at slot 2 already spent `survive`): the camp is ground and
-- the whole night's job is not being pushed off it. An enemy boot anywhere in the region stops the
-- count, so the player wins by DECIDING WHERE TO STAND -- the fire, the packs, the wounded -- rather
-- than by killing faster. That is temperance as tactics, stated once and early.
--
-- FIRST PASS. Scenes (`intro` / `outro` / the objective's `opening`) are not authored, so none is named
-- here (Conversation.play asserts on an unknown id), and the slot's own unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Starving Dark",
    description = "First night past the Lodge's last blaze. Nothing out here has eaten in weeks, and " ..
        "the fire is the only thing they can find. Hold the camp until dawn.",
    difficulty = "Normal",
    sponsor = "hunters_lodge",
    rewardItems = { "weapon_windward" },
    rewardGold = 130,
    rewardRep = 25,
    rewardPrestige = 1,
    requiredPrestige = 2,
    map = {
        biome = "forest",
        encounters = { min = 5, max = 7 },
        objective = {
            name = "The Camp",
            composition = function(ctx)
                local list = { "character_wolf_alpha" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_wolf_grunt" end
                list[#list + 1] = "character_boar"
                return list
            end,
            -- `region` defaults to "center" for a hold; named because this board IS the camp.
            -- `duration` is in TICKS (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "hold", region = "center", duration = 30 },
        },
        keyCount = 1,
    },
}
