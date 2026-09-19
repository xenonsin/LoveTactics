-- Building blueprint. THE RIFT: the mouth of the descent, and the city's front door.
--
-- IT WAS CALLED THE GATE, and the `id` still is -- ids are internal and renaming this one would touch
-- states/gate.lua, models/gate.lua, every spec that names a building and nothing the player can see.
-- What changed is the NAME, and it changed because a gate is a thing a city builds and this is a thing
-- that happened to it. There are two tears and they are the same wound: this is the one you go down
-- into, and the Crossing (data/buildings/hiring_hall.lua) is the small one above ground that people
-- come up out of. This one wears the name -- it is the older, the larger, and the one the whole city
-- grew up against -- and the other is named for what is done at it, so the two never trade places.
--
-- THE PLAYER IS TOLD THE NAME ONCE, by Rowan, in the lines that send them here ("what work The Rift is
-- offering" -- conversation_prologue_arrival). A place the fiction never names is a place the
-- player calls by whatever the card says, so those lines and this field must always agree -- the card
-- drops the article, as every plaza card does, and her line keeps it. It used to be
-- the sponsor's line, back when she intercepted the party in the street, and then the city guard's; the
-- sponsor meets them AT the stair now, so somebody who already knows the way has to name it first.
--
-- WHAT THE PLAYER IS DOING HERE. The prologue ends by walking into the capital with Rowan sworn beside
-- you, and the guard scene plays over the city. What used to happen next was the Quest Board: the seven
-- houses' work, forty days, a deadline. What happens now is that the guard points at this stair and the
-- screen behind it coaches the one button on it (states/gate.lua). A sponsor used to stand at the top of
-- the stair and say the same thing in twenty lines; she is cut. The tear in the ground is the game.
--
-- IT LEFT THE CITY AND IT IS BACK, and the round trip is worth recording because the premise moved
-- underneath it rather than anyone changing their mind. The card was deleted when the Bounty Board took
-- the campaign (3abdc941) -- posted work, a named body, a piece it owes -- and the stair went to the
-- title screen's debug column. What brings it back is the game becoming a DISTANCE RUN: how far can you
-- go, with a build you brought and a snowball you find on the way down. A board of postings names a
-- fixed errand, which is the one shape that premise has no room for.
--
-- AND THE BOARD IS PARKED THE SAME WAY THIS CARD WAS: its blueprint is deleted, so nothing in the city
-- opens it, while models/bounty.lua stays on disk and stays required by six models (player, quest, save,
-- forge, material, augment). One file undoes it. `Player.expeditionsOut` still reads bounties finished
-- alongside floors descended, deliberately -- that is what lets a save made while the board was the game
-- keep the city it had already earned.
--
-- THAT PARK WAS LIFTED AND RE-APPLIED, and the paragraph above survived both without changing a word,
-- which is exactly how a stale note reads live. The board came back in 3d155af9 as side work on the
-- houses' square, and was parked again on 2026-09-18 for a reason the distance-run argument above never
-- made: all seven of its postings are `quest_<vendor>_slot_01`, the same blueprints models/errand.lua
-- seats on a floor of the rift -- and taking one in the city handed over that house's companion without
-- a floor being walked. See docs/bounties.md.
--
-- `state` rather than `panel`: the rift is a whole screen (states/gate.lua -- the inn, the store, the
-- stair down), not a pop-up over the city. The Dueling Grounds already opens a state this
-- way, so the hub needed nothing new.
--
-- `unlockPrestige = 1` because it is the first thing there is. A city whose only door were locked would
-- be a city with nothing in it.
--
-- IT SITS IN THE MIDDLE AND IT IS DRAWN LARGER, which is the one thing on this board that is not a
-- lattice position (models/building.lua's GRID). Everything else in the city is something you do BEFORE
-- going down or BECAUSE you came back up -- hire, sleep, arm, eat, buy, spar -- so a row of equal plates
-- with the stair first among them says the wrong thing. Around it, they read as what they are: a town
-- that grew up against a hole in the ground.
return {
    name = "Rift",
    order = 1,
    x = 490,
    y = 280,
    w = 300,
    h = 170,
    state = "gate",
    sprite = "assets/hub/the_gate.png", -- falls back to its name plate until art lands
    description = "A stair down, a lamp over it, and a queue of people who need the work.",
    unlockPrestige = 1,
}
