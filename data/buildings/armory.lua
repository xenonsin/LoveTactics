-- Armory building: opens the Party screen (ui/panels/party.lua) in stash mode to arrange each
-- character's 3x3 item grid and move gear to/from the stash. Not a vendor -- it rearranges what you
-- already own (no `vendor` field, so the Party panel shows the Stash rather than a Store).
--
-- IT IS THE DOOR ONTO A BODY, all three questions of one. The panel's tabs are Loadout (what this one
-- carries), Tactics (how it fights unattended) and Jobs -- the roll, which had a card of its own on the
-- plaza until it was folded in here. What a member carries and what a member IS are one question asked
-- twice, and the portrait rail down the left is the roster either of them needs.
return {
    name = "Armory",
    order = 5,
    x = 175,
    y = 300,
    w = 270,
    h = 130,
    panel = "party",
    description = "Who is carrying what down, and what each of them is becoming.",
    unlockPrestige = 1,
}
