-- Slot 8 of the Bastion's ten: the break, and the moment the sponsor becomes the obstacle.
--
-- The order KNOWS. Not ignorance -- a decision. Its leadership found out what Acedia did, weighed a
-- hard truth against a useful saint, and took the easier one, and it has read her name aloud off the
-- front of every Oathkeeper Shield it has sold since. The doctrine that sends knights to die at posts
-- is sanctified by a woman who negotiated and walked out, and the fiction is the only thing still
-- keeping the line manned. That is the vendor quietly serving its sin, made into a room the player
-- walks into (docs/story.md).
--
-- The reward is the page itself (data/items/utility/utility_struck_name.lua), which carries Rowan's
-- third oath. She can make the narrower promise now precisely because she has learned what the wide
-- one was worth: an oath sworn to an order or an icon is worth what this page is worth. Given HERE
-- rather than after the general, so the declared guard is in hand for slots 9 and 10 -- otherwise the
-- arc resolves in dialogue instead of on the board.
-- WIP -- THIS SLOT HAS NOT BEEN THROUGH THE PREMISE PASS.
--
-- Slots 1 and 2 were rebuilt premise-first: what is actually happening, how it bears on Rowan AND on
-- sloth, what the objective is, and which unique item carries the narrative. Doing that to slot 1
-- turned up a duplicated quest with no logistics under its fiction; doing it to slot 2 turned up a
-- premise that could not survive the question "why is this a fight?" and had to be replaced
-- outright. Assume the same of this file until it has had the same pass.
--
-- Known stale here: scenes and items below were authored against the OLD slot-2 backstory (three
-- officers who turned a relief column around -- they do not exist any more; slot 2 is now the
-- nineteen who refused Acedia's terms and were struck off the rolls), and the timeline moved from
-- thirty years to fifteen. Text may still lean on beats that have been rewritten upstream.

return {
    name = "What the Bastion Knows",
    description = "Rowan wants to ask the order a question. The order would rather she did not.",
    difficulty = "Hard",
    sponsor = "bastion",
    intro = "bastion_what_the_bastion_knows_intro",
    outro = "bastion_what_the_bastion_knows_outro",
    rewardGold = 320,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "bastion", rank = 3 }, -- Banneret
    rewardItems = { "utility_struck_name" },
    map = {
        biome = "castle",
        encounters = { min = 9, max = 12, always = { "encounter_elite" } },
        objective = {
            name = "The Order's Own",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do
                    list[#list + 1] = "character_bastion_sworn"
                end
                return list
            end,
            win = { type = "assassinate", target = "character_champion" },
        },
        keyCount = 2,
    },
}
