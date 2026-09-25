-- THE GOLD GOLEM: Greed's rung-1 spare elite (reviewed over two rounds, 2026-09-25, "The Golems of
-- Greed"). The Gold Golem and two Earth Golems, and a race for the gold on the floor.
--
-- THE ESCORT IS THE HEAP SUPPLY. Earth Golems Delve and strike the vein, so new heaps keep appearing, and
-- the Gold Golem pulls them in (Gold Calls to Gold) and eats them (Regild). Without the escort it would
-- eat the two to four heaps the cave opens with and then only walk. So the company splits: somebody
-- loots, somebody breaks the escort, somebody takes the golem's fists.
--
-- AND THE DWARVES COME FOR IT (round 2, Keno's note: "have a party of enemy dwarves come in to try and
-- steal it from you"; "They come up mid-fight"). A fight has two sides, so the crew stands on the golems'
-- side and fights the company -- but it is after the gold, not after the golem: Delvers go for heaps
-- (Stout's `seeksHeaps`), so from the fourth turn the floor has three parties wanting the same coin. They
-- come up through the floor on the Seam's telegraph (`from = "below"`), and the kill-all waits for them.
--
-- The one fight where the mountain's golems and the dwarves share a board, and only because it was asked
-- for. An objective with waves is played out, never auto-resolved (EncounterBattle.eligible).
--
-- KILLALL, NEVER `assassinate`: the Hoard Falls Out is the fight's last turns, and an assassination would
-- end the fight the instant the heaps hit the floor.
local Band = require("models.band")
local Status = require("models.status")

local TURN = Status.TICKS_PER_TURN

return {
    name = "The Gold Golem",
    kind = "elite",
    weight = 2,
    -- No depth gate: its circle is its placement, and `rung` picks which of the circle's two floors
    -- (see encounter_the_king_slime.lua for the whole argument). RUNG 1 -- the approach, which had only
    -- the Fen Ooze (round 1's pick: three elites to a floor either side).
    condition = function(ctx) return ctx.biome == "cave" end,
    rung = 1,
    -- The escort is a band floored at the two the review named: one Earth Golem is too thin a heap supply.
    composition = function(ctx)
        return Band.fill({ "character_gold_golem" }, ctx, "character_earth_golem", { base = 2, min = 2, per = 7 })
    end,
    objective = {
        type = "killAll",
        waves = {
            { at = 4 * TURN, from = "below",
              composition = function()
                  return { "character_dwarf_delver", "character_dwarf_delver", "character_dwarf_goldsmith" }
              end },
        },
    },
}
