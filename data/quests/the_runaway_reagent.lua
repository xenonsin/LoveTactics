-- Slot 1 of the Crucible's ten (docs/story.md, "The Crucible: envy, designed"): the introduction, and
-- the line's horror planted before anything explains it.
--
-- The contract is dull on purpose. A consignment went missing off the college's road -- a reagent, one
-- crate, valuable, and the Crucible would like it back intact and would prefer no questions about what
-- is in it. The player takes an errand and gets the whole line's thesis in the first five minutes.
--
-- The reagent is a PERSON. A discard: a homunculus that came out hollow, eyes sewn shut, written off
-- and written down as stock (story.md, "The college, and what almost no one sees"). The thieves who
-- lifted the crate did not know either; they opened it on the road and have spent two days arguing
-- about what they are holding. Nobody in this quest is equipped to say the true sentence out loud, and
-- the player is not told it. They are simply handed a loss condition that only makes sense if the
-- cargo is alive.
--
-- That is the whole design: `assassinate` the fence, with `protect` layered under it (Combat.evaluate
-- checks `obj.protect` before the win type, so they compose). The board says recover the reagent
-- intact. The engine says the reagent can die. Nobody remarks on the gap -- the gap is the content, the
-- same call data/quests/relief_column.lua makes with its unexplained grey knight.
--
-- Ren is not in the party yet (she joins at slot 2) and no companion should explain this. Do not close
-- the gap early.
--
-- FIRST PASS. Scenes (`intro` / `outro` / the objective's `opening`) are not authored, so none is named
-- (Conversation.play asserts on an unknown id), and the slot's own
-- unbuyable is still unwritten. `character_homunculus`
-- ships and is the right body; the sewn eyes want art, not a new blueprint.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Runaway Reagent",
    description = "A crate came off the Crucible's road and the college wants it back intact. They " ..
        "are specific about intact. They are not specific about anything else.",
    difficulty = "Easy",
    sponsor = "alchemist",
    rewardItems = { "armor_reagent_vest" },
    rewardGold = 80,
    rewardRep = 20,
    rewardPrestige = 1,
    requiredPrestige = 2,
    map = {
        biome = "forest",
        encounters = { min = 4, max = 6 },
        objective = {
            name = "The Consignment",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            -- The reagent. It stands where it is put and does not fight, and the quest is lost if it
            -- dies -- which is the only place in this file the truth is stated.
            allies = { "character_homunculus" },
            win = {
                type = "assassinate",
                target = "character_bandit_chief",
                protect = "character_homunculus",
            },
        },
        keyCount = 0,
    },
}
