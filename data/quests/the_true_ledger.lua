-- Slot 7 of the Undercroft's ten: THE TURN, and the beat the whole line is built to deliver.
--
-- Clem's plan has been the same since slot 2 and it is the plan a blade would make: find the top of
-- the machine and cut it out. Burn the notes, forge the clean-slate writ, spirit the ruined away --
-- she has been doing exactly that at retail for years, and Aurea is the wholesale version of it.
--
-- The true ledger says otherwise, and it says two things.
--
-- The first: killing Aurea cancels nothing. The debt is the PACT, not the gold (docs/story.md, "Aurea,
-- the Ever-Owed") -- the notes do not lapse at her death, the laws she bought stay bought, the
-- government still owes, and the Bank crowns a new owner by the end of the week because the credit has
-- to run on. You cannot end a practice by killing its richest product, and you cannot kill an idea a
-- whole realm calls common sense.
--
-- The second is smaller and hits harder: the Bank holds Clem's own note. She was its finest blade and
-- it advanced against her the way it advances against everyone, and the entry is right there, current,
-- accruing. The jubilee is on the ledger as an asset. Her hope dies here -- that she can simply TAKE
-- freedom back -- because you cannot steal your way out of an arrangement that has already priced you.
--
-- WHY IT IS A `hold`: this is a reading, not a kill. The party is in the ledger room, Clem needs time
-- with the book, and the Bank's people are coming to close the room -- so the win condition is the
-- minutes, not the bodies. An enemy boot anywhere in the region stops the count, which means the
-- player wins by DECIDING WHERE TO STAND. The engine's `hold` is the only objective that can say "let
-- her finish reading", and this is the slot that needs it said.
--
-- Story.md flags slot 7 across every line as wanting the antagonist to SPEAK WITHOUT A FIGHT, the only
-- antagonist-dialogue seam being attached to a battle (`map.objective.opening`). Greed's turn needs
-- the seam least -- Aurea is not in the room and does not have to be; the ledger does the talking, and
-- that is exactly right for the one sin whose villain is an arrangement rather than a person.
--
-- FIRST PASS. Scenes are not authored, so no `opening` is named, and the slot's own
-- unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The True Ledger",
    description = "The book the Bank actually keeps, and Clem needs an hour with it. The Bank needs " ..
        "the room back. Hold it until she has read what she came to read.",
    difficulty = "Hard",
    sponsor = "undercroft",
    rewardItems = { "armor_unlit_hood" },
    rewardGold = 300,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "undercroft", rank = 3 }, -- Shadow
    map = {
        biome = "castle",
        encounters = { min = 8, max = 11, always = { "encounter_elite" } },
        objective = {
            name = "The Ledger Room",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            -- `region` defaults to "center" for a hold; named because this board IS the room.
            -- `duration` is in TICKS (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "hold", region = "center", duration = 32 },
        },
        keyCount = 2,
    },
}
