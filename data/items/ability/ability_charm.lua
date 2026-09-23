-- Charm: beguile a foe into fighting for you. Landing it is a roll that grows kinder the more the
-- target is hurt -- a base chance plus up to +60% as it nears death -- so Charm rewards softening a
-- victim first rather than opening with it. A boss is unmoved (never turned).
--
-- IT IS NOT FOR SALE, AND IT NEVER WAS FOR SALE HONESTLY. This sat on the thief shelf at 610 gold,
-- which said that taking a body is a technique a fence in the Undercroft can teach for money -- and it
-- is not. It is the Lust circle's own verb, the first line of Descent.SINS' entry for that stratum,
-- and there is now a body that does it for a living: the succubus line walks a Lust floor holding two
-- of the Cathedral's own, and every rung of it hands this over when it falls
-- (data/characters/character_succubus.lua). `unstocked`, so no counter deals one in either direction
-- (Vendor.foundPrice, and Vendor.sellValue reads the same answer) -- it is yours to keep, forge and
-- carry, and the only way to get one is to take it off something that used it on you.
--
-- WHICH IS ALSO WHAT MAKES ITS PAYOFF FINDABLE. utility_the_congregation -- a wound meant for you
-- splitting across everything you have Charmed -- falls off the same line, so the pair is assembled
-- out of one circle rather than out of a shelf and a corpse. That is the shape the coils already
-- have one floor over (The Slow Circle puts a body in a hold; Constrictor's Due bills it).
--
-- THE ROLL IS ALL THIS FILE OWNS. Taking the body -- the side/control flip, the stash that reverts it,
-- and the refusal on a quest objective -- belongs to the status (data/status/status_charm.lua), which
-- is where every other deliverer of Charm reaches it too: the sweetbriar, the Petal Drift, the
-- Hartwood Bride, the Chorister. This effect used to do the flip itself, and those four inflicted a
-- badge that did nothing. See docs/story.md: this is Greed's tool -- taking not a foe's gold but the
-- foe itself.
local Status = require("models.status")

return {
    name = "Charm",
    description = "Inflicts Charm, likelier the more wounded it is. Bosses are unmoved.",
    flavor = "Greed's real tool: not taking a foe's gold, but taking the foe.",
    sprite = "assets/items/ability_charm.png",
    type = "ability",
    tags = { "guile", "utility" },
    class = "thief", -- the SHELF it is graded against and never a counter that deals it: see above
    unstocked = true, -- rift-only, and unsellable with it (tests/discovery_spec.lua names it)
    unlockLevel = 13,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 6,
        cost = { stat = "mana", amount = 16 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            -- The curve moved to Status.charmChance when a second deliverer arrived (the Abbess's
            -- weapon_the_anointing). Same numbers -- 25% at full health, up to 85% near death -- in one
            -- place, so tuning it tunes both. Everything else about the roll is still this file's.
            if fx.random(100) <= Status.charmChance(t) then
                -- The caster rides along as the status's `applier` (fx.applyStatus sets it), which is
                -- how the flip knows whose side the victim now fights on. A quest objective refuses the
                -- status outright and says so in the log, so the roll above is simply wasted on one.
                fx.applyStatus(t, "status_charm")
            else
                fx.log("action", string.format("%s resists the charm.", t.char.name or "The target"))
            end
        end,
    },
}
