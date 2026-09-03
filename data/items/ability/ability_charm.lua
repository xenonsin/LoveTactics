-- Charm: beguile a foe into fighting for you. Landing it is a roll that grows kinder the more the
-- target is hurt -- a base chance plus up to +60% as it nears death -- so Charm rewards softening a
-- victim first rather than opening with it. A boss is unmoved (never turned).
--
-- THE ROLL IS ALL THIS FILE OWNS. Taking the body -- the side/control flip, the stash that reverts it,
-- and the refusal on a quest objective -- belongs to the status (data/status/status_charm.lua), which
-- is where every other deliverer of Charm reaches it too: the sweetbriar, the Petal Drift, the
-- Hartwood Bride, the Chorister. This effect used to do the flip itself, and those four inflicted a
-- badge that did nothing. See docs/story.md: this is Greed's tool -- taking not a foe's gold but the
-- foe itself.
return {
    name = "Charm",
    description = "Inflicts Charm, likelier the more wounded it is. Bosses are unmoved.",
    flavor = "Greed's real tool: not taking a foe's gold, but taking the foe.",
    sprite = "assets/items/ability_charm.png",
    type = "ability",
    tags = { "guile", "utility" },
    class = "rogue",
    discipline = "thief", -- deeper cut of the shelf: buyable only once the thief gate is cleared
    price = 660,
    unlockQuests = 7,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 6,
        cost = { stat = "mana", amount = 16 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local hp = t.char.stats.health
            local frac = (hp.max > 0) and (hp.current / hp.max) or 1
            local chance = 25 + math.floor((1 - frac) * 60) -- 25% at full health, up to 85% near death
            if fx.random(100) <= chance then
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
