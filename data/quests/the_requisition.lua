-- Slot 6 of the Arcanum's ten: complicity, and the hand that feeds the next working.
--
-- NOT a grind. No quest in this game is `repeatable`, and a farmable version of this beat would teach
-- the opposite of what it is for: the point is not that the Arcanum's appetite is endless (the player
-- can infer that), it is that the player fills ONE requisition without reading it and then finds out
-- what it was for.
--
-- So it is a single large order for a single named working. Everything on one list, one trip, under
-- seal, with the quantities specified and the nouns euphemised the way an institution euphemises when
-- it is not hiding anything and simply has house style. The player has been reading Arcanum paperwork
-- since slot 5 and has learned, the way everyone in this house learns, to stop parsing it -- which is
-- the exact habit the whole institution runs on (docs/story.md: everyone above them is a customer).
--
-- They are told what the working is on delivery, as a courtesy, because the Magus is proud of it and
-- it is genuinely going to save a city. That is the slot. Not a trick, not a reveal -- a receipt.
--
-- What it costs Gyeom: she reads the requisition. She reads all of them, every line, which is a thing
-- the player may have noticed her doing since slot 4 and not asked about. She does not tell them what
-- is on it beforehand, and afterwards she does not say she told them so, because she did not.
--
-- `reach` (region "far") rather than a clear: the job is to GET THERE and get out with it. Whatever is
-- guarding the site was not put there by the Arcanum and is not the Arcanum's problem -- a sentence
-- from the work order, and the only joke in the file.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Requisition",
    description = "One order, under seal, for one named working. Quantities specified, nouns in " ..
        "house style. Whatever is guarding the site was not put there by the Arcanum.",
    difficulty = "Hard",
    sponsor = "arcanum",
    rewardItems = { "armor_sealed_coat" },
    rewardGold = 240,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "arcanum", rank = 3 }, -- Magus
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Collection Point",
            composition = function(ctx)
                local list = { "character_gaunt_vigil" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_zombie" end
                return list
            end,
            win = { type = "reach", region = "far" },
        },
        keyCount = 1,
    },
}
