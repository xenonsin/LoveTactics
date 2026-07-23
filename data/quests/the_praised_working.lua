-- Slot 3 of the Arcanum's ten (docs/story.md, "The Arcanum: pride, designed"): the complication, and
-- the cost the beneficiaries never see.
--
-- The Arcanum is not a mask over a dungeon and this quest must not play like one. It is a genuinely
-- indispensable institution: it wins the realm's wars, breaks its sieges, turns back its plagues, and
-- the crown consults it. The working at the centre of this quest WORKED. It broke a siege, it is named
-- in a proclamation, and there are people alive in a city eighty miles away because of it.
--
-- It was practised on a village first. Not maliciously and not secretly -- as a trial, with paperwork,
-- on people whose consent was a formality nobody thought to withhold, and the village is still here and
-- still wrong. That is the whole sin stated once, early: no one else can do what we do, so nothing we
-- do can be wrong, and everyone above them is a customer (story.md, "The Arcanum, and what it is
-- allowed to do").
--
-- What it costs Gyeom: she came up inside this house and would not adopt its one rationalization. She
-- is not surprised by any of it. What the slot costs her is that she has to be USEFUL here in front of
-- the player, and being useful means working the same craft -- and she does it quietly, at exactly the
-- size the job needs, which will read to the player as a small mage doing small things. That reading is
-- the point, and the finale collects on it.
--
-- `survive`: the residue of the trial is still in the ground and it comes up at night. There is no mark
-- and nothing to clear -- the village needs one night held, and by morning the thing is gone the way it
-- has gone every night for two years. Nothing is fixed. That is the slot.
--
-- FIRST PASS. Scenes (`intro` / `outro` / the objective's `opening`) are not authored, so none is named
-- (Conversation.play asserts on an unknown id), and the slot's own unbuyable is still unwritten.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Praised Working",
    description = "The proclamation names the working that broke the siege. It does not name the " ..
        "village it was practised on, which is still here, and still wrong.",
    difficulty = "Normal",
    sponsor = "arcanum",
    rewardItems = { "weapon_reflecting_wand", "armor_witchlight_shroud" },
    rewardGold = 130,
    rewardRep = 25,
    rewardPrestige = 1,
    requiredPrestige = 2,
    map = {
        biome = "forest",
        encounters = { min = 5, max = 7 },
        objective = {
            name = "What Comes Up at Night",
            composition = function(ctx)
                local list = { "character_gaunt_vigil" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_zombie" end
                return list
            end,
            -- TICKS to outlast (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "survive", duration = 30 },
        },
        keyCount = 1,
    },
}
