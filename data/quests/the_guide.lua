-- Near the head of the Hunter's Lodge's ten (docs/story.md, "The Hunter's Lodge", slot 2). How Kaya is
-- recruited (character_kaya.lua): the Lodge's board pushes the player deeper and deeper after the
-- "greatest game," and no outsider reaches the heart of the deep wood without someone the wild knows.
-- Pushed too deep, the player is nearly swallowed by the maddened, starving beasts Gula's spreading kills
-- have driven wild -- and Kaya and her wolf turn it back.
--
-- A `survive` objective, NOT a purge: she is never an enemy here. Hold out until the wild settles, and
-- she takes the party in. `rewardCharacter` grants her on the win (Player.recruit refuses a duplicate).
-- The `opening` is her arrival; the victory `outro` (kaya_joins) is where she agrees to guide -- for her
-- own reason, that the thing devouring the wood is devouring the living world she is part of.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Guide",
    description = "Pushed deep after the Lodge's bounty, you are nearly swallowed by a wood gone mad " ..
        "with hunger. Outlast it -- and pray the wild has a hunter of its own.",
    difficulty = "Normal",
    sponsor = "hunters_lodge",
    rewardItems = { "weapon_corvids_bow", "armor_bogwalkers_coat" },
    rewardGold = 90,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 2,
    rewardCharacter = "character_kaya",
    outro = "kaya_joins",
    map = {
        biome = "forest",
        encounters = { min = 4, max = 6 },
        objective = {
            name = "The Maddened Wood",
            composition = function(ctx)
                local list = { "character_dire_bear" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_wolf_grunt" end
                list[#list + 1] = "character_boar"
                return list
            end,
            opening = "hunters_lodge_the_guide_confront",
            win = { type = "survive", duration = 36 }, -- TICKS to outlast (the clock's unit)
        },
        keyCount = 0,
    },
}
