-- Charm: beguile a foe into fighting for you. Landing it is a roll that grows kinder the more the
-- target is hurt -- a base chance plus up to +60% as it nears death -- so Charm rewards softening a
-- victim first rather than opening with it. A boss is unmoved (never turned). On a hit the effect
-- itself performs the side/control flip and stashes the originals on the unit; the Charm status
-- (data/status/charm.lua) is the timer that reverts them on expiry. See docs/story.md: this is Greed's
-- tool -- taking not a foe's gold but the foe itself.
return {
    name = "Charm",
    description = "Turns a foe to your side -- likelier the more wounded it is. Bosses are unmoved.",
    flavor = "Greed's real tool: not taking a foe's gold, but taking the foe.",
    sprite = "assets/items/ability_charm.png",
    type = "ability",
    tags = { "guile", "utility" },
    class = "rogue",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 6,
        cost = { stat = "mana", amount = 16 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            if t.char.boss then
                fx.log("action", string.format("%s is unmoved.", t.char.name or "The target"))
                return
            end
            local hp = t.char.stats.health
            local frac = (hp.max > 0) and (hp.current / hp.max) or 1
            local chance = 25 + math.floor((1 - frac) * 60) -- 25% at full health, up to 85% near death
            if fx.random(100) <= chance then
                -- Flip the victim onto the caster's side under AI control, stashing what to restore.
                -- Guard on the status so a refresh (re-charm) doesn't overwrite the stash with the
                -- already-flipped values.
                if not fx.hasStatus(t, "status_charm") then
                    t._charmSide, t._charmControl = t.side, t.control
                    t.side, t.control = fx.user.side, "ai"
                end
                fx.applyStatus(t, "status_charm")
            else
                fx.log("action", string.format("%s resists the charm.", t.char.name or "The target"))
            end
        end,
    },
}
