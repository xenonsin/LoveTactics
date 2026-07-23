-- Slot 4 of the Cathedral's ten (docs/story.md, "The Cathedral: lust, designed"): the escalation, and
-- the first time the player is asked to look at what they are killing.
--
-- The church hires out purges of "corruption from the wild" and it has hired out a great many. This
-- one is inside the fold -- a village the Cathedral serves, its own charity houses, its own people --
-- and the things loose in it are not from the wild at all. They are FAILED BLOODINGS (story.md, "The
-- blooding"): children the rite took wrong, feral and half-made, hunted by the institution that made
-- them under a name that keeps anyone from asking a second question.
--
-- Amana's plea at slot 2 told the player WHAT is happening. This is the slot that makes them see it,
-- and the sight is deliberately withheld until now: they have already run one purge for this church
-- without knowing, and slot 6 will have them run more.
--
-- What it costs Amana: she was kept back as an acolyte -- clergy, never blooded -- and these are the
-- other track. She knows some of these by name and says the names out loud while the party fights,
-- which is the only thing she can still do for them.
--
-- `killAll`: there is no mark and no room to reach. The horror of the slot is that clearing the board
-- IS the job, and the job is what the church wanted.
--
-- FIRST PASS. Scenes are not authored, so no `intro` / `outro` / `opening` is named (Conversation.play
-- asserts on an unknown id). `character_anointed_failed` is the blueprint this slot actually wants
-- (story.md's not-built list); `character_demon_imp` and `character_demon_grunt` stand in, which is
-- itself the church's lie wearing the engine's clothes and should not survive the art pass.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Purge in the Fold",
    description = "Corruption from the wild, the Cathedral says, in a village the Cathedral feeds. " ..
        "Clear it -- and look at what you are clearing.",
    difficulty = "Normal",
    sponsor = "cathedral",
    rewardItems = { "weapon_gag_crook" },
    rewardGold = 180,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "cathedral", rank = 2 }, -- Acolyte
    map = {
        biome = "forest",
        encounters = { min = 6, max = 8, always = { "encounter_elite" } },
        objective = {
            name = "The Fold",
            composition = function(ctx)
                local list = { "character_demon_grunt" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_demon_imp" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
