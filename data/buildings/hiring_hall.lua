-- Building blueprint. THE HERO'S RIFT: where a company comes from.
--
-- THE CITY HAS TWO TEARS IN IT AND THEY ARE THE SAME WOUND. The big one is the stair
-- (data/buildings/the_gate.lua, "The Rift") and you go DOWN into it. This one is small, it is above
-- ground, and people come UP out of it. That is the whole fiction and it is the whole mechanic: the
-- player is a tactician who stands in no company, so every body that walks down the stair is somebody
-- this tear gave up.
--
-- IT WAS THE HIRING HALL and it was a room with a desk in it. The name went for the reason the Gate's
-- did: a hall is a building and a rift is the premise. A city that grew up against a hole in the ground
-- does not have a recruitment office, it has a second hole that occasionally hands you a swordsman.
--
-- WIZARDRY'S TAVERN DID THIS JOB FIRST, and the thing it got right is worth keeping through the
-- reskin: you keep no roster of your own creations, so instead of forming a party from characters you
-- rolled, you take on people who will go. What has changed is that the town no longer DEALS them off a
-- shelf -- a rift is opened with a token carried up from below (models/voucher.lua), so the depth you
-- reached is what decides who can come through.
--
-- `id` stays `hiring_hall`, which is internal and referenced by the tutorial's coached stage
-- (states/hub.lua) and three specs. Renaming it would touch all of that and nothing the player sees.
return {
    name = "Hero's Rift",
    order = 2,
    x = 175,
    y = 120,
    w = 270,
    h = 130,
    panel = "hiring",
    -- IT KEEPS A VENDOR ID WITHOUT KEEPING A SHELF, exactly as the Cafe and the Touchstone do: what
    -- that buys is a KEEPER -- the portrait the panel draws, the name, and the one-time first-visit
    -- greeting (states/hub.lua's vendor scenes) -- and the hub's first-visit machinery is keyed on a
    -- building naming a vendor. `sells = false` on the blueprint keeps it off every shelf, and having
    -- no `class` keeps it off the market board (tests/hub_spec.lua).
    vendor = "heros_rift",
    unlockPrestige = 1,
}
