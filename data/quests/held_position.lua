-- Slot 3 of the Bastion's ten: the complication, and it goes wrong in SLOTH's specific way rather
-- than a generic one.
--
-- A garrison that will not stand down. Their post has no wall left behind it and no purpose left in
-- front of it, and they are still there, because the doctrine says hold until relieved and nobody has
-- come to relieve them. The player is sent to hold it WITH them -- a `hold` objective, which is the
-- knight's entire thesis finally sayable: standing on the ground is not enough, an enemy boot on any
-- of it stops the count, and you win by DECIDING WHERE TO STAND rather than by killing faster.
--
-- The unease this plants is the one the line needs early: Rowan defends their refusal far too hard,
-- and hears herself do it. Diligence with no mercy in it looks exactly like this, and it is the first
-- hint that her answer has a failure mode of its own -- an unlimited promise that never chooses.
return {
    name = "Held Position",
    description = "A watchpost stands with nothing behind it and nobody coming. Its garrison will " ..
        "not leave. Stand with them until the assault breaks.",
    difficulty = "Normal",
    sponsor = "bastion",
    rewardGold = 130,
    rewardRep = 20,
    rewardPrestige = 1,
    requiredPrestige = 2,
    map = {
        biome = "castle",
        encounters = { min = 6, max = 8 },
        objective = {
            name = "The Post With Nothing Behind It",
            composition = function(ctx)
                local list = { "character_demon_grunt", "character_demon_grunt" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_demon_imp" end
                return list
            end,
            -- `region` defaults to "center" for a hold; named here because this board IS the post.
            win = { type = "hold", region = "center", turns = 6 },
        },
        keyCount = 1,
    },
}
