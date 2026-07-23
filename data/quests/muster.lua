-- Slot 6 of the Bastion's ten: complicity, and the one day a year the order counts itself.
--
-- NOT a grind. No quest in this game is `repeatable` any more, and this file used to be the argument
-- for why not: its whole theme was the repetition -- another name off the roll, Rowan's lines shorter
-- each run -- which asks the player to farm a quest in order to feel something about farming it. That
-- is a beat delivered by a design document rather than by a player, and most players never saw it,
-- because nobody replays a bounty they have already cleared.
--
-- Said once, on a date, it lands. The muster is the season's oath, sworn at the tent, the ceremony the
-- order has held every year since anyone can remember -- and the queue at the tent is shorter than it
-- was last year, and shorter than the year before, and nobody standing in it remarks on this. The
-- order casts the same number of billet rations every season and has stopped running out (the flavour
-- on data/items/consumable/consumable_bannerets_steel.lua is exactly this fact, written on a tin).
--
-- The day's work is the long list: the last open entries closed in one sweep so the roll is clean for
-- the swearing. The Bastion does not ask why any of them set the shield down -- that is slot 4's
-- discovery (data/quests/the_long_list.lua) -- and the muster is the ritual built on top of not asking.
--
-- What it costs Rowan: she swears the season's oath with them, in a half-empty tent, and means every
-- word of it. The player is the only one there who has been to Greywatch.
--
-- WIP -- THIS SLOT HAS NOT BEEN THROUGH THE PREMISE PASS. The scenes below (`bastion_muster_intro` /
-- `_outro`) were authored to read the same on the fifth run as the first, which is precisely the shape
-- a one-off does not want; they want a rewrite against the ceremony.
--
-- Known stale here: text authored against the OLD slot-2 backstory (three officers who turned a relief
-- column around -- they do not exist any more) and against a thirty-year timeline that is now fifteen.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Muster",
    description = "The season's oath is sworn at the tent on Sunday, and the roll wants closing " ..
        "before it is read. The queue is shorter than last year. Nobody has mentioned it.",
    difficulty = "Normal",
    sponsor = "bastion",
    intro = "bastion_muster_intro",
    outro = "bastion_muster_outro",
    -- A ration of billet steel, handed out at the tent with the oath. Granted once, like every other
    -- quest reward in the game now that nothing is repeatable -- see the item's own header.
    rewardItems = { "consumable_bannerets_steel", "weapon_debt_bell" },
    rewardGold = 240,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "bastion", rank = 3 }, -- Banneret
    rewardMaterials = { material_steel_ingot = 2 },
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_forsworn" } },
        objective = {
            name = "The Last Names on the Roll",
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
