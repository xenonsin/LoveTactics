-- The Draft Yard: the door into Draft mode (states/draft.lua) from the city.
--
-- Unlike every other building here it is not a pop-up over the town -- Draft is a whole mode with its
-- own screen, so this def names a `state` instead of a `panel` and the hub switches to it (see
-- states/hub.lua). Leaving the mode comes back to the city, not to the title screen.
--
-- Ungated. Draft is a side mode that borrows the campaign's units and items but shares none of its
-- progression -- a run is drafted from scratch every time -- so there is nothing for prestige or a
-- quest to be a gate ON, and it is offered on the title screen with no gate either.
--
-- Narrow because it is squeezed into the left edge of the bottom row, mirroring the Dueling Grounds
-- at the other end: the two "fight somebody who isn't the world" doors book-end the row.
return {
    name = "Draft Yard",
    order = 9,
    x = 10,
    y = 530,
    w = 175,
    h = 140,
    state = "draft",
    unlockPrestige = 1,
}
