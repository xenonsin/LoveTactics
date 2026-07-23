-- Slot 4 of the Undercroft's ten: the escalation, and the trace-up.
--
-- The player has been running contracts for a firm with no sign and no door you would notice, and the
-- contracts have come from everywhere: a merchant house, a magistrate, a shipping concern, a widow.
-- This is the quest where they cross-reference, and the answer is that there is ONE CLIENT. Every
-- writ the Undercroft has handed them traces up through two or three respectable intermediaries to the
-- Bank, which is the beloved institution with its name on the hospital and the library.
--
-- The outlaws are the establishment. That is the sentence the slot exists to deliver, and it is worse
-- than a conspiracy because it is not one: nothing is hidden, the intermediaries are real firms doing
-- real business, and the arrangement is exactly as legal as everything else the Bank owns (docs/
-- story.md, "The Bank, and what everyone already accepts"). Corruption is not its crime, it is its
-- product, sold back to everyone as prudence.
--
-- Why it is a fight: cross-referencing means getting into a clearing house that has no reason to let
-- anyone read its correspondence, and the men in it are a private security detail with a lawful
-- retainer. They are not criminals. Neither, technically, is the player.
--
-- What it costs Clem: nothing she did not know. What it costs her is watching the player find out, and
-- having to not say the part she is still holding -- that the Bank holds her own note. Slot 7 is where
-- that lands.
--
-- `killAll`: a clearing house, and the whole room is the obstacle. No mark, because the point of the
-- slot is that there is no one person to cut out.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own
-- unbuyable is still unwritten. The Bank's
-- security detail wants a bespoke blueprint; `character_bandit_chief` and `character_champion` stand
-- in, and should not read as thugs when they get one.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "One Client",
    description = "Every writ the Undercroft has handed you traces up through two or three " ..
        "respectable firms to the same address. It is the one with its name on the hospital.",
    difficulty = "Normal",
    sponsor = "undercroft",
    rewardItems = { "weapon_mired_kris" },
    rewardGold = 180,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "undercroft", rank = 2 }, -- Prowler
    map = {
        biome = "castle",
        encounters = { min = 6, max = 8, always = { "encounter_elite" } },
        objective = {
            name = "The Clearing House",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
