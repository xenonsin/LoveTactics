-- Slot 9 of the Arcanum's ten: the approach, and the scale of what killing her will NOT undo.
--
-- The house does not panic and does not close ranks. It PLANS. With Sublimitas about to be a problem
-- one way or another, the inner circle does the sensible institutional thing and begins selecting her
-- successor -- openly, with a shortlist, because the realm still wants what only this place can do and
-- an Arcanum without an Unequalled is an Arcanum that loses its contracts (docs/story.md).
--
-- That is the whole beat. The dead she raised do not lie back down at her death. The subjects do not
-- return. The proclamations stay proclaimed, the crown stays a customer, and there is already a name
-- being written under hers. The player is not walking toward a cure; they are walking toward the end
-- of one woman, and the line says so a quest early rather than letting the finale pretend otherwise.
--
-- What it costs Gyeom: the shortlist has her name on it. Not as a joke -- as a serious entry, put
-- there by people who watched her refuse the chair at slot 8 and read the refusal as leverage. The
-- house cannot imagine a mage who does not want the summit, so it has priced her as one holding out
-- for more. She has to look at her own name on that list and keep walking, which is the last thing
-- humility costs her before the finale.
--
-- `assassinate`: the shortlist's favourite, met defending the selection -- and he fights the way the
-- house trains, which is to say by showing the player everything he has, immediately, because being
-- seen is the entire point of him.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own
-- unbuyable is still unwritten. The
-- favourite wants a bespoke blueprint with a portrait; `character_mage` stands in.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Next Unequalled",
    description = "The inner circle has begun selecting her successor. There is a shortlist, it is " ..
        "not secret, and Gyeom's name is on it.",
    difficulty = "Hard",
    sponsor = "arcanum",
    rewardItems = { "weapon_unravelling_wand", "armor_unravelling_habit" },
    rewardGold = 400,
    rewardRep = 35,
    rewardPrestige = 2,
    requiredPrestige = 5,
    requiredRep = { vendor = "arcanum", rank = 3 }, -- Magus
    map = {
        biome = "castle",
        encounters = { min = 10, max = 13, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "The Shortlist's Favourite",
            composition = function(ctx)
                local list = { "character_mage" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_priest" end
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_zombie" end
                return list
            end,
            win = { type = "assassinate", target = "character_mage" },
        },
        keyCount = 2,
    },
}
