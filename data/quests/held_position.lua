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

--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Held Position",
    description = "A watchpost stands with nothing behind it and nobody coming. Its garrison will " ..
        "not leave. Stand with them until the assault breaks.",
    difficulty = "Normal",
    sponsor = "bastion",
    intro = "bastion_held_position_intro",
    outro = "bastion_held_position_outro",
    rewardItems = { "consumable_watchpost_draught", "weapon_unclosing_edge" },
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
            -- `duration` is in TICKS (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "hold", region = "center", duration = 30 },
        },
        keyCount = 1,
    },
}
