-- The explosive barrel: a keg of lamp oil and powder standing wherever the last garrison left it. The
-- first prop (models/prop.lua), and the one the whole layer was shaped around.
--
-- It has ONE rule: hit it and it goes off. That is `health = 1` plus onDestroy -- any blow that lands
-- on it is a killing blow, so a stray arrow, a spilled AoE, a body knocked into it and the barrel's own
-- neighbour all set it off identically. There is no second way to trigger it and no timer to read: the
-- board asks the same question every time, which is "is anything I care about standing next to that?"
--
-- The blast takes EVERYONE in radius 1, friend and foe alike, exactly as trait_volatile does
-- (data/traits/trait_volatile.lua -- the Bomblet is the walking version of this object). It also chains:
-- any other `explosive` prop caught in the ring goes off in turn, so a stack of kegs is one shot away
-- from taking a whole quarter of the board. The chain terminates because a prop is marked dead before
-- its onDestroy runs, so a barrel can never be set off by the neighbour it just set off.
--
-- Tagged `fire`, so armour reads nothing on it but fire-resist does -- the blast is mitigated like any
-- other hit (ctx.damage), which keeps "stand behind the knight" a real answer to a barrel as well as to
-- a demon.
--
-- Two things follow from `health = 1` for free, with no code anywhere:
--   * HEAVED into anything, it bursts on impact -- the collision damages it (Combat.hurlObject), and
--     damage is its only trigger. Throwing a barrel into a shield wall is a written ability nobody wrote.
--   * Shot from range, it costs nothing but the shot. Popping one at distance is always available, which
--     is what keeps a cluttered board a puzzle rather than a tax.
return {
    name = "Explosive Barrel",
    description = "A keg of oil and powder. Anything that hits it sets it off.",
    sprite = "assets/props/explosive_barrel.png", -- placeholder until its own art exists
    color = { 0.62, 0.31, 0.16 }, -- rust-red staves, for the renderer's fallback block
    health = 1,        -- one blow, any blow: the barrel has no HP to speak of, only a trigger
    blocksMove = true, -- it stands on its tile; walk around it or shove through it
    sightCost = 0,     -- waist-high: you can shoot straight over it, which is the point of shooting it
    magnitude = 16,    -- blast power before mitigation (a placing ability scales this via prop.amount)
    radius = 1,
    tags = { "prop", "explosive", "flammable" },
    -- Which biomes leave powder lying around, and how much of it. A castle yard and the underworld are
    -- built on the stuff; a forest trail has whatever a passing caravan dropped, so barrels are rare
    -- there and crates (data/props/prop_crate.lua) are what you mostly find instead.
    biomes = { castle = 3, underworld = 3, forest = 1 },
    onDestroy = function(ctx)
        local blast = ctx.power
        if blast <= 0 then return end
        local r = ctx.prop.def.radius or 1
        for _, u in ipairs(ctx.unitsNear(ctx.prop.x, ctx.prop.y, r)) do
            if u.alive then ctx.damage(u, blast, { "fire", "impact" }) end
        end
        -- Chain: every other keg in the ring goes up too. Aimed at the whole neighbourhood rather than
        -- filtered to explosives here, because a barrel bursting on a crate SHOULD splinter the crate --
        -- the crate simply has no onDestroy to answer with, and an inert prop breaking is the correct
        -- outcome of standing next to a bomb.
        for _, p in ipairs(ctx.propsNear(ctx.prop.x, ctx.prop.y, r)) do
            if p ~= ctx.prop then ctx.damageProp(p, blast) end
        end
    end,
}
