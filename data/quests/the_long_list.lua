-- Slot 4 of the Bastion's ten: the escalation, and the first real cost.
--
-- The order keeps a list of knights who set their shields down and it sends people to close the
-- entries. This is the first one, and the point of the scene is that she is SYMPATHETIC and she is
-- right: the post she left was written off before she left it, and she says so, and the Bastion has
-- sent you anyway. Rowan gets angry -- at her, loudly, and out of proportion -- because the woman is
-- describing something Rowan has decided cannot be true of the order.
--
-- `assassinate` rather than killAll: her hands are a wall to get through, not a thing to grind down.
-- The quest is a killing, and it should be possible to do it without killing everyone she had left.
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
    name = "The Long List",
    description = "The Bastion keeps a list of knights who set their shields down, and it would like " ..
        "one of the entries closed.",
    difficulty = "Normal",
    sponsor = "bastion",
    intro = "bastion_the_long_list_intro",
    outro = "bastion_the_long_list_outro",
    rewardItems = { "utility_closed_entry" },
    rewardGold = 180,
    rewardRep = 25,
    rewardPrestige = 1,
    requiredPrestige = 2,
    requiredRep = { vendor = "bastion", rank = 2 }, -- Sworn
    map = {
        biome = "forest",
        encounters = { min = 7, max = 9, always = { "encounter_forsworn" } },
        objective = {
            name = "An Entry on the List",
            composition = function(ctx)
                local list = { "character_forsworn_captain" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do
                    list[#list + 1] = "character_forsworn_knight"
                end
                return list
            end,
            win = { type = "assassinate", target = "character_forsworn_captain" },
            -- Played over the board with the captain standing on it. He cannot speak from `intro`
            -- (that runs over the hub) or `outro` (by then he is the assassinate target, dead).
            opening = "bastion_the_long_list_confront",
        },
        keyCount = 1,
    },
}
