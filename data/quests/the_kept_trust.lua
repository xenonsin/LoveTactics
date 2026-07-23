-- Slot 8 of the Cathedral's ten: the break, and the Kept-Trust beat.
--
-- Amana's virtue is devotion read exactly: she gives what is offered and refuses what is not, which is
-- the precise inverse of the sin she is answering -- Luxuria takes what was never offered
-- (docs/story.md, `trait_rapture`). The failure mode of that virtue is that it gives EVERYTHING, and
-- eight quests of it have left her with nothing of her own. The church taught her that, too.
--
-- So the beat is this: she keeps one thing for herself, and the whole point is that it is not a theft.
-- It was hers, it was given to her, and the chancery has come to collect it back under seal along with
-- everything else in her cell -- because an acolyte who has started asking about the register is a
-- woman whose effects the Cathedral would like to inventory. She says no. Out loud, to the institution
-- that raised her, and that "no" is the same sentence her whole virtue is made of, turned around and
-- pointed at herself for the first time.
--
-- The sponsor is the obstacle from here on. The Cathedral does not excommunicate her and does not
-- accuse her; it sends people to take her things, which is worse, and much more like a church.
--
-- `assassinate`: the chancery's seal-bearer is the mark, and his party is a wall to get through
-- rather than a thing to grind down. He is doing paperwork and he will not stop for an argument.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. NOTE ON REWARDS: the Kept Trust itself
-- (data/items/utility/utility_reliquary_kept_trust.lua) already ships in Amana's starting grid, so it
-- is deliberately NOT granted here -- this is the quest that explains why she still has it. Story.md
-- budgets one unbuyable at slot 8 per line; that item is not written yet.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Kept Trust",
    description = "The chancery has come to inventory Amana's cell under seal. She has one thing in " ..
        "it she was given, and she is not handing it over.",
    difficulty = "Hard",
    sponsor = "cathedral",
    rewardItems = { "weapon_censer_of_the_unravelling" },
    rewardGold = 320,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "cathedral", rank = 3 }, -- Confessor
    map = {
        biome = "castle",
        encounters = { min = 9, max = 12, always = { "encounter_elite" } },
        objective = {
            name = "The Seal-Bearer",
            composition = function(ctx)
                local list = { "character_priest" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_knight" end
                return list
            end,
            win = { type = "assassinate", target = "character_priest" },
        },
        keyCount = 2,
    },
}
