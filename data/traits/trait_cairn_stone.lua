-- CAIRN STONE: the Cairn-Keeper's trophy on the Warlord's shelf (data/items/utility/utility_cairn_stone.lua;
-- "Sloth's Bestiary", 2026-10-04, slice C). While the bearer stands, allies within 3 cannot be moved, Charmed or
-- Taunted. The bearer counts as one of them.
--
-- Two flags and no hooks. `wardsAllies` is the Sire's Signet's ward, narrowed by `wardRadius` to the stone's
-- reach (Status.allyWard); `anchorsAllies` is read by Status.blocksForcedMove (models/sloth_bog.lua's anchored),
-- so a shove, a pull or a throw finds nothing to move -- the blow itself still lands.
return {
    name = "Cairn Stone",
    description = "While you stand, allies within 3 cannot be moved, Charmed or Taunted.",
    wardsAllies = { "status_charm", "status_taunt" },
    wardRadius = 3,
    anchorsAllies = 3,
    notAReaction = true,
}
