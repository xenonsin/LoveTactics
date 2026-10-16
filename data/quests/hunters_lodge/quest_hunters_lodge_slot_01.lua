-- KAYA'S HUNT. The Lodge calls it a cull. Something in the whiteout takes and takes, and the ground behind
-- it has gone quiet. It comes down once, and nothing else in there does. Her wolf goes in first.
--
-- RESTORED 2026-10-14 (data/quests went in 92ff549d, and with it every way a companion could join).
-- SHE IS MET IN SLOTH, not in the Lodge's own circle: Gyeom is scripted onto floor one, which is
-- Gluttony's, and no two companions share a circle (Descent.COMPANION_CIRCLE). So the quarry is that
-- circle's own: the FROST WORM, the one body on Sloth's approach that is a hunt rather than a brawl -- a
-- wagon-train of white worm whose trill is a wind-up the company has to read -- with the YETIS of the
-- whiteout for its pack, whose roar roots anybody standing alone. A hunter's fight: keep together, read
-- the trill, bring the big thing down. A third yeti joins on the circle's second floor.
--
-- It was a white stag and its boars in Gluttony's wood, and the meeting lines still say so
-- (conversation_hunters_lodge_errand_found): those are the author's to rewrite.
--
-- NO GOODS: the Deadfall Bow and the Quarryhide are hunter-ladder finds now (rungs 9 and 5). The purse
-- stays.
return {
    name = "Quiet in the Whiteout",
    description = "Something in the whiteout has eaten the quiet out of the place. A hunter has been " ..
        "waiting at the edge of it for it to come down.",
    difficulty = "Normal",
    sponsor = "hunters_lodge",
    outro = "conversation_hunters_lodge_slot_01_outro",
    rewardGold = 130,
    rewardCharacter = "character_kaya",
    -- READ ONLY BY models/balance.lua, which still measures a quest's bodies at a campaign standing:
    -- the standing at the first floor of the circle she is met in (Sloth, floor eleven on the authored
    -- order), so a deep circle's stock is judged against the company that actually meets it.
    requiredPrestige = 9,
    map = {
        -- The ground of that circle. The descent picks its own ground off the floor, so this is the
        -- authored claim tests/biome_spec.lua validates, not what draws the board.
        biome = "tundra",
        objective = {
            name = "The Quiet Ground",
            composition = function(ctx)
                local list = { "character_frost_worm", "character_yeti", "character_yeti" }
                -- Read off depth, which every fight's context carries, rather than `ctx.rung`, which not
                -- every caller fills in.
                if require("models.descent").floorWithinCircle(ctx.depth or 1) >= 2 then
                    list[#list + 1] = "character_yeti"
                end
                return list
            end,
            win = { type = "assassinate", target = "character_frost_worm", enemy = "the frost worm" },
        },
    },
}
