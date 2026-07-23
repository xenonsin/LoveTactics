-- A hammer, so it stuns (docs/weapons.md). Its extra is that the stun SPREADS: the blow lands on one body
-- at full weight and the ring of tiles around it takes half the damage and a shorter stun. The only area
-- control on the fighter's shelf.
--
-- Quest-only: `class` with no `price`.
--
-- What it buys is the thing a hammer has never been able to do, which is matter against more than one
-- person. The family's whole economy is one enormous turn spent to take one turn away, and against three
-- foes that is a losing rate however hard the blow lands. This makes it one turn for three, at a discount
-- on each -- and the discount is where it stays honest, because a full stun on a whole ring would simply
-- end fights.
--
-- Read against data/items/weapon/weapon_slow_verdict.lua, which is the other way to fix the same maths:
-- that one makes the single stun so long it is worth the tempo, this one makes the tempo buy several
-- shorter ones. Depth against breadth, and the axe family's argument imported into the hammer's.
--
-- The ring is unsided. Swing it into a melee your own line is standing in and you have stunned your own
-- line, which is a genuinely bad turn -- the same rule the axe's arc runs on.
return {
    name = "Bellfounder's Hammer",
    description = "Stuns the target, and rattles a shorter stun into everything standing around them.",
    flavor = "A bellfounder strikes once and the whole village hears about it. The principle transfers.",
    sprite = "assets/items/bellfounders_hammer.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "fighter",
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 8, -- slower even than an iron hammer: the ring is paid for in tempo, as everything here is
        cost = { stat = "stamina", amount = 14 },
        -- Under an iron hammer's, per body. The breadth is the extra and it must not also be depth.
        damage = { 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local cx, cy = t.x, t.y
            fx.damage(t, { inflicts = "status_stun" })
            -- The ring: half the swing, and a stun of roughly half an ordinary one's shove. Read from
            -- the STRUCK tile rather than from the wielder, so the ring is centred on the blow.
            local share = math.max(1, math.floor((fx.amount or 0) / 2))
            for _, u in ipairs(fx.unitsNear(cx, cy, 1)) do
                if u ~= t and u ~= fx.user and u.alive then
                    fx.damage(u, { amount = share, inflicts = { id = "status_stun", magnitude = 3 } })
                end
            end
        end,
    },
}
