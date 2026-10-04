-- WHITEOUT: the Dread of the Whiteout's rule (data/items/utility/utility_the_whiteout.lua), and the Whiteout
-- Cloak's (data/items/armor/armor_whiteout_cloak.lua). Approved 2026-10-04 on "Sloth's Bestiary", slice A.
--
-- Unseen to anything more than 2 tiles away: the Shadow Mantle's flag (`concealedBeyond`, read in one place by
-- Status.concealedAt) at a range of 2. So it binds the player's aim as well as the planner's, and it answers to
-- what that flag answers to: a Limned bearer, a lantern or a bell is seen from anywhere, and a body that comes
-- within 2 can strike it. The review's counter, "Limn her, or keep a body near enough to see her", is both of those.
return {
    name = "Whiteout",
    description = "Unseen to foes more than 2 tiles away.",
    concealedBeyond = 2,
}
