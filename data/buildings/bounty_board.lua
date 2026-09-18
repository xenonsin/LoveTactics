-- Building blueprint. THE BOUNTY BOARD: work the seven houses post, a day's walk out and back.
--
-- WHAT IT IS. A row is a BOUNTY -- a ground, a tier, a body standing at the end of it, and the one
-- piece that body gives up -- and taking it spends the posting whether the run is won or lost
-- (models/bounty.lua, docs/bounties.md). Where the Rift asks how deep you are willing to go, this asks
-- what you are willing to go and get.
--
-- IT WAS THE CAMPAIGN'S PREMISE AND IT IS SIDE WORK NOW, and that demotion is the whole reason this
-- file reads differently from the one it replaces. The card was deleted outright in 002d1f38 when the
-- descent became the game again; `models/bounty.lua` stayed on disk and the seven ladders with it, so
-- the un-park is this blueprint and nothing else. What it must NOT do is stand in the middle of the
-- plaza again -- the old card was drawn larger and centred, on the argument that a town reads as
-- "arranged around the work that pays for it", and the work that pays for it is the stair.
--
-- WHY IT IS WITH THE HOUSES RATHER THAN OUT ON THE PLAZA, which is a deviation worth stating plainly:
-- the city plaza is FULL. Nine slots (models/building.lua's GRID.city -- three columns by three rows,
-- with the Rift taking the middle), and nine cards standing in them; the Inn took the last free one in
-- dc7be9df. The choice was to shove a tenth plate on top of a ninth -- the exact bug that card's own
-- header records, two plates drawing over each other with a "???" printing through a name -- or to put
-- the board where its posters already are.
--
-- The houses district IS the right home on the design as well as on the geometry. Seven shopfronts, and
-- this is the sheet the seven of them pin their work to; a player looking for a house's errand is
-- already on this screen. Reached from the Houses card on the plaza, one door in rather than a front
-- door of its own -- which is what "posted side work, not the premise" looks like in a layout.
--
-- THE THIRD ROW IS NEW and centred under the seven (GRID.houses runs four across, then three; this sits
-- alone below both). 561 + 130 clears the 720 floor with room, and a single centred plate under an
-- odd-numbered row reads as a footer to it rather than as the start of a row that never arrived.
--
-- IT WAITS FOR ITS FIRST TENANT (`unlockAnyHouse`), the same gate the Houses card in the city carries
-- and for a stronger reason: a board is a sheet the seven pin work to, and with no house open there is
-- nobody to have pinned anything. The old card sat on `unlockPrestige = 1` alone, on the argument that a
-- city whose only doors were locked has nothing in it -- true of a FRONT door on the plaza, and not of
-- this one, which is already two doors in behind a gate of its own.
--
-- It also keeps the square honest: tests/hub_spec.lua asserts every plate here is shut on a fresh save,
-- and a live board standing among seven "???" plates would be the one thing on the screen that does not
-- belong to the tableau.
--
-- The postings behind it have their own gates on top of this (a house's standing, the ladder rung), and
-- those do the real work of deciding what is actually on the sheet.
return {
    name = "Bounty Board",
    district = "houses",
    -- NOT ONE OF THE SEVEN, said out loud because tests/hub_spec.lua checks that every card on this
    -- board names a vendor and a class gate -- which is a rule worth keeping teeth in, since a house
    -- missing either has a door that can never open. This is the sheet they post to rather than a
    -- shopfront, so it is the one card here that is exempt, and it has to declare that rather than be
    -- inferred from the absence of a field it might simply have been missing.
    noticeBoard = true,
    order = 8, -- after the seven; it is the sheet they post to, not one of them
    x = 505,
    y = 561,
    w = 270,
    h = 130,
    panel = "bounty_board",
    sprite = "assets/hub/bounty_board.png", -- falls back to its name plate until art lands
    description = "Posted work, a day's walk out: a ground, a body at the end of it, and what it owes.",
    unlockAnyHouse = true, -- see above; nobody has posted anything until somebody is renting a shopfront
    unlockPrestige = 1,
}
