-- Slot 8 of the Hunter's Lodge's ten: the break, and the temperance beat in its personal form.
--
-- The Lodge's masters find out what the party saw at slot 7, and they do the institutional thing: they
-- do not silence Kaya, they PROMOTE her. The offer is genuine and it is generous and it is made in
-- front of witnesses -- the Grand Hunter's title, the range, the standing, everything the guild has to
-- give its greatest. Refusing it is not a gesture; it costs her the only sanctioned life her craft has
-- (docs/story.md: "the honor they offer their greatest is the very thing she declines").
--
-- She declines. Then the master who made the offer explains, reasonably, that a tracker who knows what
-- rank four is and will not take it is a problem the Lodge cannot leave in the wood -- and this is
-- where the sponsor becomes the obstacle.
--
-- The temperance beat is the fight itself, and it is the line's thesis said in one motion: Kaya takes
-- ONE shot and stops. Not because one is enough to win -- because stopping is a thing she does on
-- purpose, and a hunter who cannot stop is the entire disease she is walking toward. Stopping is not
-- quitting. That distinction is the whole difference between her and Gula and it has to be shown here,
-- cheap and small, so the last arrow at slot 10 reads as a decision rather than a cutscene.
--
-- `assassinate`: the master who made the offer, and the hunters he brought to make it. They are
-- colleagues, they are not evil, and most of them think they are collecting a fugitive.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. This slot owes KAYA'S SECOND RELIC (the
-- Wolfsong Horn is her first; see story.md's relic section) and the line's slot-8 unbuyable; neither is
-- written, so no `rewardItems` entry points at them. `character_bandit_chief` and `character_archer` stand
-- in for the Lodge's hunters, who want their own blueprints.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "One Shot, and Stop",
    description = "The Lodge has offered Kaya the title, in front of witnesses. She has said no, and " ..
        "the man who offered it cannot leave a hunter who knows what the title is out in the wood.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardItems = { "weapon_held_breath" },
    rewardGold = 320,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "hunters_lodge", rank = 3 }, -- Beastslayer
    map = {
        biome = "forest",
        encounters = { min = 9, max = 12, always = { "encounter_elite" } },
        objective = {
            name = "The Master Who Made the Offer",
            composition = function(ctx)
                local list = { "character_warlord" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_archer" end
                return list
            end,
            win = { type = "assassinate", target = "character_warlord" },
        },
        keyCount = 2,
    },
}
