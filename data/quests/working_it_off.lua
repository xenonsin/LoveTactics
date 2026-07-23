-- Slot 3 of the Undercroft's ten (docs/story.md, "The Undercroft: greed, designed"): the complication,
-- and the first time the machine is shown rather than described.
--
-- A debtor was "recruited" to work it off. That is a real offer, made in good faith by people who
-- believe it, and it is the cleanest single illustration of what the Bank actually sells: the wage is
-- credited against the note, the lodging is deducted, the tools are deducted, the interest runs the
-- whole time, and the balance is larger than it was two years ago. Nobody stole anything. Nobody broke
-- a law -- the Bank buys the statutes that make its work lawful by construction (story.md, "The Bank,
-- and what everyone already accepts"), so there is nothing here to expose. There is only arithmetic
-- that never clears, being administered by ordinary people who would be offended to hear it called
-- cruelty.
--
-- Why it is a fight: the man has stopped working, which under the terms is default, and default is
-- the one thing the Undercroft is retained for. The collectors are on the road ahead of the party.
--
-- What it costs Clem: she ran these routes. She knows the deduction schedule from memory and recites
-- it before she reads it, which is how the player learns what she was without her saying so.
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so the two compose): clear the collectors, and the debtor lives. Saving him settles nothing -- the
-- note survives him, and slot 7 is where that lands -- but the quest is not asking that yet.
--
-- FIRST PASS. Scenes (`intro` / `outro` / the objective's `opening`) are not authored, so none is
-- named (Conversation.play asserts on an unknown id), and the slot's own unbuyable is still unwritten.
-- `character_survivor` stands in for the debtor; the collectors want their own blueprint -- they are
-- clerks with an escort, not brigands.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Working It Off",
    description = "He took the offer two years ago: work the debt down, lodging deducted, tools " ..
        "deducted. The balance is larger now than when he started, and he has stopped turning up.",
    difficulty = "Normal",
    sponsor = "undercroft",
    rewardItems = { "armor_smokecloth_wrap" },
    rewardGold = 130,
    rewardRep = 25,
    rewardPrestige = 1,
    requiredPrestige = 2,
    map = {
        biome = "forest",
        encounters = { min = 5, max = 7 },
        objective = {
            name = "The Collection Party",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            allies = { "character_survivor" },
            win = { type = "killAll", protect = "character_survivor" },
        },
        keyCount = 1,
    },
}
