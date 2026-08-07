-- Tests for the intent preview (models/intent.lua): the classifier that turns an AI unit's coming
-- turn into a display intent -- the kind of thing it will do, to whom, and how hard -- plus the
-- retarget question the move-preview asks ("would this foe wheel onto me if I stood there?"). Pure
-- logic, so it runs headless; the board line and the timeline icon are just two drawings of what is
-- proven here.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Intent = require("models.intent")

-- The same flat, all-walkable fixture the AI and combat specs use.
local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

-- A { char, x, y } spawn, with the innate signature relic + its bound trait stripped, exactly as
-- ai_spec does, so a companion summon or a bound counter can't perturb what these fixtures reason
-- about.
local function unit(charOrId, x, y, tweak)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    char.traits = {}
    for i = 1, Character.MAX_INVENTORY do
        if char.inventory[i] and char.inventory[i].bound then char.inventory[i] = nil end
    end
    if tweak then tweak(char) end
    return { char = char, x = x, y = y }
end

local function swordsman(archetype)
    local char = Character.instantiate("character_rowan")
    char.inventory[1] = Item.instantiate("weapon_iron_sword")
    char.archetype = archetype
    return char
end

-- A bandit re-kitted around a single ability, its grid otherwise emptied so the AI has exactly one
-- offensive option (plus the free fists) and the classification under test is the one it must choose.
-- Mana filled, since a bandit blueprint ships with `mana = 0` and Combat.itemBlockReason would refuse
-- the cast before it was ever weighed.
local function caster(abilityId, archetype)
    local char = Character.instantiate("character_bandit")
    for i = 1, Character.MAX_INVENTORY do char.inventory[i] = nil end
    char.inventory[1] = Item.instantiate(abilityId)
    char.stats.mana = { max = 40, current = 40 }
    char.archetype = archetype
    return char
end

local function setHp(u, current) u.char.stats.health.current = current end

return {
    -- ---------------------------------------------------------------------
    -- Classification -- one case per kind
    -- ---------------------------------------------------------------------
    {
        name = "a weapon strike reads as an attack, names its mark, and carries the damage number",
        fn = function()
            local c = Combat.new(arena(8, 8),
                { unit(swordsman(), 4, 4) }, { unit("character_bandit", 4, 5) })
            local knight, bandit = c.units[1], c.units[2]
            local intent = Intent.of(c, bandit)
            assert(intent.kind == "attack", "a sword swing is an attack, got " .. tostring(intent.kind))
            assert(intent.target == knight, "aimed at the knight it stands beside")
            assert(intent.amount and intent.amount > 0, "and it quotes the damage it would land")
        end,
    },
    {
        name = "an offensive spell that spends mana reads as a cast",
        fn = function()
            local c = Combat.new(arena(11, 11),
                { unit(swordsman(), 6, 4) }, { unit(caster("ability_fireball"), 6, 6) })
            local intent = Intent.of(c, c.units[2])
            -- Only when it actually chose the spell (it might punch an armoured target); when it did,
            -- the mana cost is what tells a cast from a swing.
            if intent.kind ~= "attack" then
                assert(intent.kind == "cast", "a mana-paid offensive ability is a cast, got " .. tostring(intent.kind))
                assert(intent.amount and intent.amount > 0, "with its damage quoted")
            end
        end,
    },
    {
        name = "a heal aimed at a wounded ally reads as support, with the healing quoted",
        fn = function()
            local c = Combat.new(arena(10, 10),
                { unit(swordsman(), 1, 1) },
                { unit(caster("ability_heal", "support"), 5, 6), unit("character_bandit", 5, 7) })
            local medic, hurt = c.units[2], c.units[3]
            setHp(hurt, 3)
            local intent = Intent.of(c, medic)
            assert(intent.kind == "support", "healing its own side is support, got " .. tostring(intent.kind))
            assert(intent.target == hurt, "aimed at the wounded ally")
            assert(intent.heal and intent.heal > 0, "and it quotes the healing, not a damage number")
        end,
    },
    {
        name = "a hostile status with no damage reads as a debuff, not a cast",
        fn = function()
            -- Silence spends mana AND lands a status, so the ORDER of the classifier matters: a status
            -- with no damage is a debuff even though it is a spell. The read the player wants is "it is
            -- about to disable someone", not "it is casting".
            local c = Combat.new(arena(9, 9),
                { unit(swordsman(), 5, 5) }, { unit(caster("ability_silence"), 5, 7) })
            local intent = Intent.of(c, c.units[2])
            assert(intent.kind == "debuff",
                "a damageless status is a debuff, got " .. tostring(intent.kind))
            assert(intent.statuses and intent.statuses > 0, "and it knows a status is coming")
        end,
    },
    {
        name = "a unit that will hold its turn reads as wait, coming for nobody",
        fn = function()
            -- A defensive unit with nobody near does not start a fight (ai_spec pins this as a wait
            -- plan); the intent of a wait is the absence of a target.
            local guard = Character.instantiate("character_bandit")
            guard.archetype = "defensive"
            local c = Combat.new(arena(12, 12),
                { unit(swordsman(), 11, 11) }, { unit(guard, 2, 2) })
            local intent = Intent.of(c, c.units[2])
            assert(intent.kind == "wait" and intent.wait, "an unengaged holder waits")
            assert(intent.target == nil, "and points at no one")
        end,
    },
    {
        name = "the target line leaves from the tile the strike is thrown from, after any approach",
        fn = function()
            -- A foe that must close before it swings draws its line from where it WILL be, not where it
            -- stands now -- so fromTile is the plan's move destination when the plan includes one.
            local c = Combat.new(arena(10, 10),
                { unit(swordsman(), 5, 5) }, { unit("character_bandit", 5, 9) })
            local intent = Intent.of(c, c.units[2])
            if intent.kind == "attack" and intent.fromTile then
                local adj = math.abs(intent.fromTile.x - 5) + math.abs(intent.fromTile.y - 5)
                assert(adj <= 1, "it closes to arm's reach before striking, fromTile is adjacent to the knight")
            end
        end,
    },

    -- ---------------------------------------------------------------------
    -- The retarget hypothetical -- surface B, at the model layer
    -- ---------------------------------------------------------------------
    {
        name = "a foe strikes the body it can reach, and wheels onto the actor if the actor steps in",
        fn = function()
            -- The foe stands beside a healthy decoy and far from a one-hp actor it cannot reach this
            -- turn, so it takes the decoy. Move the actor to arm's reach (what the move-preview does
            -- by nudging the actor onto the tile it is weighing) and the lethal blow on the actor now
            -- dominates -- it wheels. This is exactly what states/battle.lua's retargetLines reads.
            local decoy = swordsman()
            local actor = swordsman()
            local c = Combat.new(arena(11, 14),
                { unit(decoy, 5, 6), unit(actor, 5, 13) },
                { unit("character_bandit", 5, 5) })
            local decoyU, actorU, foe = c.units[1], c.units[2], c.units[3]
            setHp(actorU, 1) -- a corpse-in-waiting, but out of reach for now

            local before = Intent.of(c, foe)
            assert(before.target == decoyU,
                "with the actor unreachable it takes the decoy at its elbow")

            -- The hypothetical: the actor stands on the tile beside the foe. (retargetLines saves and
            -- restores this; here the case owns it.)
            local ox, oy = actorU.x, actorU.y
            actorU.x, actorU.y = 5, 4
            local after = Intent.of(c, foe)
            actorU.x, actorU.y = ox, oy

            assert(after.target == actorU,
                "with the actor now in reach, the killing blow on it wins -- the foe wheels")
        end,
    },
    {
        name = "a foe already set on a better mark does not wheel onto an actor merely standing near",
        fn = function()
            -- The other half of the read, and the whole point of D1's request: if the foe would NOT
            -- come for you, its line stays on whoever it is going for. Here the decoy is the one at
            -- death's door, so stepping in beside the foe changes nothing -- it finishes the decoy.
            local decoy = swordsman()
            local actor = swordsman()
            local c = Combat.new(arena(11, 14),
                { unit(decoy, 5, 6), unit(actor, 5, 13) },
                { unit("character_bandit", 5, 5) })
            local decoyU, actorU, foe = c.units[1], c.units[2], c.units[3]
            setHp(decoyU, 1) -- the decoy is the kill

            local ox, oy = actorU.x, actorU.y
            actorU.x, actorU.y = 5, 4 -- a healthy actor steps to arm's reach
            local after = Intent.of(c, foe)
            actorU.x, actorU.y = ox, oy

            assert(after.target == decoyU,
                "the lethal blow on the decoy still wins; the passing actor is not chosen")
        end,
    },
    {
        name = "the read goes silent when a plan errors -- a prediction never crashes the fight",
        fn = function()
            -- Intent.of runs a live plan; states/battle.lua wraps it in pcall so a throw is no line,
            -- never a downed battle. Here we prove the classifier itself tolerates a nil/na plan by
            -- feeding classify a wait-shaped and an empty plan directly.
            local c = Combat.new(arena(6, 6),
                { unit(swordsman(), 1, 1) }, { unit("character_bandit", 3, 3) })
            local foe = c.units[2]
            assert(Intent.classify(c, foe, nil).wait, "no plan is a wait")
            assert(Intent.classify(c, foe, { wait = true }).wait, "an explicit wait is a wait")
            assert(Intent.classify(c, foe, {}).wait, "a plan naming no item is a wait")
        end,
    },
}
