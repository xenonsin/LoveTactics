-- Slot 7 of the Hunter's Lodge's ten: THE TURN, and the beat the whole line is built to deliver.
--
-- The Lodge's rot is not its rank and file, who are decent, and it is not a mask over a slaughterhouse.
-- It is the thing the guild does to its GREATEST (docs/story.md, "The Lodge, and what almost no one
-- sees): hunt the sacred long enough and the hunter becomes the apex predator at the wild's centre --
-- the very thing the Lodge exists to hunt. Rank 4 is a fattening. The board never closes because the
-- prey renews itself out of the hunters' own ranks, and the trophies on the Lodge wall used to have
-- names.
--
-- The player has already read one of those names off a wall at slot 5. This is where they meet one
-- turning. A Grand Hunter of nine years ago, most of the way over, still wearing what is left of her
-- kit and still -- for the first few seconds -- able to speak. She knows what is happening to her. She
-- knew before she took the title, because everyone at the top does, and she took it anyway, and that
-- is the sentence the slot exists for.
--
-- What it costs Kaya: everything she was holding out. She is exactly the tracker the Lodge would love
-- to crown, and this is the crown, and it was offered to her too. "There but for restraint" is not a
-- line anybody says; it is the reason she has to sit down afterwards.
--
-- Story.md flags slot 7 across every line as wanting the antagonist to SPEAK WITHOUT A FIGHT, with the
-- only seam for antagonist dialogue currently attached to a battle (`map.objective.opening`). This one
-- needs it least of the six: the turning warden CAN speak, briefly, and then cannot, and the fight is
-- what her not being able to speak looks like. The premise survives if the no-fight seam is built.
--
-- `assassinate`: she is the mark, and what is left of her pack is a wall to get through. Not `killAll`
-- -- the wood around her is not the point and should be walkable past.
--
-- FIRST PASS. Scenes are not authored, so no `opening` is named. `character_ogre` stands in for the
-- turning warden (a hulking 2x2 body is the right silhouette for something most of the way over); the
-- slot wants its own blueprint, with a name on it, because the name is the horror.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "What the Honor Makes",
    description = "Kaya has found the thing the Lodge calls a warden of the deep wood. It is nine " ..
        "years since it was given a title, and for a few seconds it can still talk.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardItems = { "weapon_unravelling_shaft", "armor_raveners_hide" },
    rewardGold = 300,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "hunters_lodge", rank = 3 }, -- Beastslayer
    map = {
        biome = "forest",
        encounters = { min = 8, max = 11, always = { "encounter_wolf", "encounter_elite" } },
        objective = {
            name = "The Warden That Had a Name",
            composition = function(ctx)
                local list = { "character_ogre" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_dire_bear" end
                return list
            end,
            win = { type = "assassinate", target = "character_ogre" },
        },
        keyCount = 2,
    },
}
