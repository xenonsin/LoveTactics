-- Slot 9 of the Colosseum's ten: the approach, and the last thing the player learns before the sand.
--
-- The stable is cornered -- the intake ledger is out, the day is named, the league's other houses have
-- started asking -- and the quest is about what it does INSTEAD of confessing. It does not fight for
-- its secret and it does not deny it. It closes the program: the trainers who ran the intake are put
-- on a card and killed in front of a paying crowd, which is legal, which is sport, and which leaves
-- nothing behind but a good night's gate receipts.
--
-- That is wrath's institutional face and the reason the general is not the disease. A house that
-- discovered rage outperforms morale will spend anyone, including its own architects, before it will
-- say a true sentence -- and killing Ira does not touch it. The Perennial will be training again inside
-- a year, because the league still pays for what only this house can put on the sand.
--
-- What it costs Saber: nothing left to cost. She goes because the people about to die on that card are
-- the people who made her, and she will not let it be a show. This is the last quiet before slot 10.
--
-- `assassinate`: the mark is the lanista running the disposal, and his card is a wall to get through.
--
-- FIRST PASS. Scenes are not authored, so no `intro` / `outro` / `opening` is named.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "What the House Does Instead",
    description = "Cornered, the stable has scheduled its own trainers onto a card. It is legal, it is " ..
        "sport, and by morning there will be nothing left to ask about.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardItems = { "weapon_kingsfall", "weapon_anvil_of_the_ninth", "weapon_whitening", "armor_last_stand_plate" },
    rewardGold = 400,
    rewardRep = 35,
    rewardPrestige = 2,
    requiredPrestige = 5,
    requiredRep = { vendor = "colosseum", rank = 3 }, -- Champion
    map = {
        biome = "castle",
        encounters = { min = 10, max = 13, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "The Disposal Card",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            -- The trainers, on the sand and not fighting back. Losing them costs the run: the whole
            -- point of the slot is that the house is destroying its own evidence, and the player is
            -- the only one in the building trying to stop it.
            allies = { "character_survivor", "character_survivor" },
            win = { type = "assassinate", target = "character_champion", protect = "character_survivor" },
        },
        keyCount = 2,
    },
}
