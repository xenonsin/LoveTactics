-- Slot 4 of the Crucible's ten: the escalation, and the quest where the Work is shown WORKING.
--
-- Slot 3 showed the college's product failing on a man who could not carry it. This is the other half,
-- and the line does not land without it: the buyers who can. The Crucible sells qualities by the dram
-- to people with the standing to be topped up, and against a party of ordinary bodies they are
-- genuinely, offensively better -- faster, stronger, more precise than anyone in the room earned any
-- right to be. Their enforcers are the same, and the first blank homunculi are on the floor with them,
-- fetching and dying and getting back up.
--
-- The point is not that this is monstrous. The point is that it is EFFECTIVE, and that everyone who
-- can afford it is buying, and that the philosophy underneath it is the one thing standing between the
-- player and a world where excellence is inventory.
--
-- What it costs Ren: she watches the Work done brilliantly and hates that it works. She is the best
-- alchemist in the room and she is fighting people wearing purchased versions of what she spent her
-- life earning, and the honest answer -- that hers holds and theirs does not -- is worth nothing at all
-- in the next ten minutes. This is where kindness starts costing her something.
--
-- `killAll`: a buyers' salon with its hired hands, and there is no mark to cut out. Clearing the room
-- is the job, and the room is what the college sold.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own unbuyable is still unwritten.
-- `character_homunculus` ships (the blanks); `character_champion` and `character_mage` stand in for
-- the topped-up buyers and their enforcers, who want bespoke blueprints -- statlines that read as
-- bought rather than trained.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "By the Dram",
    description = "The college sells by the dram to people who can be topped up. Tonight they are all " ..
        "in one room, and they are better than they have any right to be.",
    difficulty = "Normal",
    sponsor = "alchemist",
    rewardItems = { "armor_everdraught_bandolier" },
    rewardGold = 180,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "alchemist", rank = 2 }, -- Distiller
    map = {
        biome = "castle",
        encounters = { min = 6, max = 8, always = { "encounter_elite" } },
        objective = {
            name = "The Salon",
            composition = function(ctx)
                local list = { "character_champion", "character_mage" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_homunculus" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
