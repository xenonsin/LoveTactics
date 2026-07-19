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
return {
    name = "The Long List",
    description = "The Bastion keeps a list of knights who set their shields down, and it would like " ..
        "one of the entries closed.",
    difficulty = "Normal",
    sponsor = "bastion",
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
        },
        keyCount = 1,
    },
}
