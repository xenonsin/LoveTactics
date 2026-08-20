-- Building blueprint. THE INN: the only place in the game that sets a bone.
--
-- WHAT IT IS FOR. A body that goes down in a fight comes out of it WOUNDED (models/wound.lua) -- a share
-- of its health pool reserved and unreachable, and debuffs stacking as they accumulate -- and nothing
-- underground can undo that. The rest stop on a floor gives back half of what is left; only a night here
-- gives back the body. A company that keeps descending without stopping keeps getting worse, and this is
-- the door that costs money to make it stop being true.
--
-- Priced per head (models/gate.lua's Gate.INN_PER_HEAD), so a full company is dearer than a lone
-- survivor -- which is the right way round, since a full company is exactly when a night is worth most.
--
-- IT WAS A ROW ON THE GATE SCREEN. The town is the town -- the tavern where you find people, the inn
-- where you sleep, the houses where you buy -- and the gate is a stair with a lamp over it whose only
-- job is to go down. Wizardry's own split: the castle holds the counters, the dungeon entrance sits at
-- the edge of town where there is nothing to do but enter.
--
-- IT ARRIVES ON THE FIRST WOUND (models/wound.lua's Wound.everWounded). Setting a bone is the only thing
-- this door does -- the hub already restores health and mana on the way in (Player.restore) -- so a
-- company that has never had anybody go down in a fight has nothing to buy here, and a card offering it
-- is a price quoted for a service the player cannot yet want. The night the first body is carried up
-- broken is the night the sign goes up.
--
-- ONE-WAY, and the mark rather than the ledger is why: `wounds` empties when the surgeon is paid, so a
-- door reading it would come off the plaza the morning after it was used.
return {
    name = "The Inn",
    order = 3,
    x = 490,
    y = 120,
    w = 300,
    h = 130,
    panel = "inn",
    description = "A night here sets the bones nothing underground will.",
    -- IT KEEPS A VENDOR ID WITHOUT KEEPING A SHELF, exactly as the Cafe, the Touchstone and the Hero's
    -- Rift do: what that buys is a KEEPER -- the portrait the panel draws, the name, and the one-time
    -- first-visit greeting (models/vendor_visit.lua) -- and the hub's first-visit machinery is keyed on
    -- a building naming a vendor. `sells = false` on the blueprint keeps it off every shelf, and having
    -- no `class` keeps it off the market board (tests/hub_spec.lua).
    vendor = "inn",
    unlockWound = true, -- see models/building.lua
    unlockPrestige = 1,
}
