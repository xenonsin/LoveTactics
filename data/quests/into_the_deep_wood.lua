-- Slot 9 of the Hunter's Lodge's ten: the approach, and the scale of what killing her will NOT undo.
--
-- The last leg in, guided, past the range where the blazes stopped mattering. Nothing here is a
-- revelation; the revelations are spent. What the slot delivers is the WOOD -- kill after kill left
-- where it fell and not eaten, the whole downstream of it thin and wrong and empty, and a silence that
-- the player has already been told about at slot 5 and now has to walk through for an hour.
--
-- Gula wastes nearly all of it. The thrill is the point, never the meat (docs/story.md, "Gula, the
-- cursed hunter"), and the deep wood she stripped does not grow back at her death. Nor does the
-- appetite die with her: it is the Lodge's, not hers alone, and the guild will crown its next Grand
-- Hunter, who will in time be the next thing at the centre. The player is not walking toward a cure.
-- They are walking toward the end of one hunter, and the line says so a quest early rather than
-- letting the finale pretend otherwise.
--
-- What it costs Kaya: nothing left to cost -- slot 8 spent it. She is quiet the whole way in, and the
-- question she is sitting with is the only one temperance ever has to answer: whether a kill that is
-- not for food betrays the balance she keeps. The answer she arrives at is that NECESSITY, not
-- appetite, is what temperance is for, and she does not say it out loud until the last arrow.
--
-- `assassinate`: the crowned apex's court -- the strongest of what is left ranging around her -- and
-- the mark is the one holding the trail shut. The rest of the wood is a wall to walk past.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The slot wants bespoke blueprints for the
-- half-turned things at the wood's heart -- previous years' Grand Hunters, and each ought to be
-- individually recognisable; `character_ogre` and `character_dire_bear` stand in.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Into the Deep Wood",
    description = "Past the last blaze, into a wood that has been eaten and not fed on. Everything " ..
        "here was killed for the pleasure of it and left where it fell.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardItems = { "weapon_sunfall", "weapon_last_word" },
    rewardGold = 400,
    rewardRep = 35,
    rewardPrestige = 2,
    requiredPrestige = 5,
    requiredRep = { vendor = "hunters_lodge", rank = 3 }, -- Beastslayer
    map = {
        biome = "forest",
        encounters = { min = 10, max = 13, always = { "encounter_elite", "encounter_wolf" } },
        objective = {
            name = "The Shut Trail",
            composition = function(ctx)
                local list = { "character_ogre" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_dire_bear" end
                list[#list + 1] = "character_wolf_alpha"
                return list
            end,
            win = { type = "assassinate", target = "character_ogre" },
        },
        keyCount = 2,
    },
}
