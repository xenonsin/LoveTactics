-- GORE: the boar picks a line, tells you about it, and then runs down it.
--
-- The one thing on the board that asks a spatial question other than "how far away am I". Every other
-- enemy in the game is answered by distance -- close it, keep it, break it. This one is answered by
-- the LINE you are standing on, and the counterplay is a step sideways that no amount of retreating
-- substitutes for.
--
-- THE TELL IS THE ABILITY. The wind-up commits the lane on the beat it is declared (Combat.useItem's
-- channel branch stores tx/ty), states/battle.lua paints every in-progress channel's footprint on the
-- board, and the boar cannot re-aim once it has planted its feet. Long enough that a body of ordinary
-- speed gets a turn to leave, and short enough that leaving has to be the turn you spend rather than
-- something you fit around what you were already doing -- see the note on `windup` for what the
-- measured cost of a longer one turned out to be.
--
-- AND THE COUNTERPLAY IS NOT THE DODGE. Stepping aside is the floor, not the answer -- a boar that
-- misses turns around and re-aims, and a fight that was only that would be a fight about patience. The
-- answer is to make it MISS INTO SOMETHING: the run stops dead on a wall, furniture, impassable ground
-- or the board's edge (Combat.chargeInto), and a run stopped short puts the animal on the floor. So
-- the real play is to stand on the line deliberately, with stone behind you, and get off it late.
-- Cover stops being a thing you hide behind and becomes a thing you aim an animal at.
--
-- The stun is what pays for that read, and it pays twice: `status_stun` also carries
-- `disablesReactions`, so a boar that has knocked itself silly is a boar whose Feral Instinct counter
-- (utility_feral_instinct) is switched off. The reflex that normally punishes you for closing is gone
-- for exactly the window you earned by steering the charge. Nothing had to be authored for that; the
-- two rules simply meet.
--
-- WHY IT AIMS THE FAR TILE AND CARRIES ITS OWN FOOTPRINT. Two engine facts decide this file's shape,
-- and both of them break the obvious version:
--
--   * The AI can only plan an ability against a foe inside `range` (Combat.abilityTargets). Aiming the
--     ADJACENT tile the way ability_charge does -- `range = 1` -- means an enemy holding this would
--     only ever consider it against a body already standing next to it, and would never once fire down
--     a lane. That ability's own header flags the hole; this one cannot live with it.
--   * A `shape = "line"` AoE aimed at reach starts AT the aimed cell and extends AWAY from the caster
--     (Combat.aoeCells). Aimed at a foe three tiles off it would cover that foe and the ground behind
--     it -- not the ground the boar runs THROUGH, which is the entire footprint this needs.
--
-- So it aims the foe (the AI plans it) and authors its own footprint (`aoe.cells`, the data-file hook
-- Combat.aoeCells offers, as utility_wolfsong_horn does) covering the LANE tiles ahead of the boar.
-- The telegraph, fx.aoeUnits and the AI's own scoring then all read one and the same set of tiles.
--
-- `minRange = 2` is what keeps it a charge rather than a shove: a foe already adjacent is not a foe you
-- get a run-up at, so the boar bites that one instead (weapon_tusks). And because the footprint is the
-- lane rather than a radius, a foe standing in range but OFF the line is caught by nothing -- the
-- planner prices the cast at zero and refuses it (AI.scoreCandidate's `outcome` gate). The boar charges
-- when you are on its line and only then, enforced by arithmetic rather than by a rule anybody wrote.
local Curve = require("models.curve")

-- Tiles of run, and the reach, in one number: the lane the footprint paints, the distance the rush
-- covers, and (as `range`) how far down it the planner may aim. They must agree -- a reach longer than
-- the lane would let the boar commit to a foe its run can never arrive at.
local LANE = 3

-- Combat's own stepToward, which is private to that module and cannot be reached from a data file.
-- Duplicated rather than approximated: the footprint below has to pick the SAME axis the rush will
-- (Combat.chargeInto's signDominant is this function), or the tiles painted are not the tiles crossed.
local function step(ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    if math.abs(dx) >= math.abs(dy) then
        if dx == 0 then return 0, 0 end
        return (dx > 0) and 1 or -1, 0
    end
    return 0, (dy > 0) and 1 or -1
end

return {
    name = "Gore",
    description = "Winds up, then charges three tiles in a straight line, goring everything on it.",
    flavor = "It has already decided. The only question left is who is still standing there.",
    sprite = "assets/items/ability_gore.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "creature",
    noSteal = true, -- the animal's own rush; there is no trinket here to lift
    activeAbility = {
        target = "tile",
        allowOccupied = true, -- the lane is aimed at a body, so the planner can see it (see the header)
        range = LANE,
        minRange = 2,         -- adjacent is a bite, not a charge
        -- THE WIND-UP IS THE PRICE, AND IT IS THE ONLY PRICE. `speed` is what the turn bills on top of
        -- the tell, and billing a slow action there as well charges twice for one commitment. All three
        -- numbers below were MEASURED rather than judged, through models/autobattle.lua over eight
        -- boards, because the planner cannot see any of this: AI.scoreCandidate prices an action's
        -- stamina and its steps and nothing else, so a wind-up costs the enemy AI exactly nothing to
        -- consider and it will take a telegraphed blow over a jab every time it scores higher. An
        -- ability whose whole cost is invisible to the thing choosing it has to be priced here.
        --
        -- The first cut ran windup 3 at speed 4 -- seven ticks against a jab's two -- and took the
        -- ordinary boar fight from 16 unit-turns to 25. Halving the tell to two made it WORSE (30),
        -- because the cheaper it got the more the planner reached for it, and each cast was still worth
        -- about a bite and a half for three bites' tempo. What actually settles it is the stamina:
        --
        -- COST 10 IS THE WHOLE BAR. The boar carries 10 stamina and regains 1 a tick, so the charge is
        -- an OPENER -- one per animal per engagement, and a biter for the ten ticks afterwards, which is
        -- both what the measurement wanted and what the animal should be. Measured over eight boards it
        -- lands tempo-neutral (27.1 unit-turns average against 27.4 carrying no charge at all): the
        -- fight is no longer, it is differently shaped. Four ticks of cast at speed 2 keeps the tell
        -- worth reading, and the run carries the boar three tiles on an action it did not spend its move
        -- on, which is most of what makes the trade honest. tests/skirmish_spec.lua is what caught the
        -- first two cuts and is what will catch the next one.
        speed = 2,
        windup = 3,           -- the lane is committed here, and everyone gets to read it
        cost = { stat = "stamina", amount = 10 },
        -- The slot-0 ability number (ability_fire_bolt's own curve), and deliberately NOT more. An
        -- item's `damage` is ADDED to the bearer's own Damage, so the boar's 14 is most of what lands
        -- either way -- a gore is about 13 where a jab is about 12, and doubling this figure to 10
        -- bought a 40% harder blow while reading on the shelf ladder as a 100% outlier
        -- (Balance.magnitudeVerdict). What makes the charge worth taking is the LANE and the ground it
        -- crosses, not a bigger number; if it ever needs to hit harder, that is a second body standing
        -- on the line, which is the decision this whole ability exists to pose.
        damage = Curve.ramp(6, 16),
        -- The lane: the tiles ahead of the BOAR, not around the tile it aimed at. See the header on
        -- why the built-in "line" shape is the wrong footprint for a charge.
        aoe = {
            cells = function(_, tx, ty, unit)
                if not unit then return { { x = tx, y = ty } } end
                local dx, dy = step(unit.x, unit.y, tx, ty)
                if dx == 0 and dy == 0 then return {} end
                local out = {}
                for i = 1, LANE do
                    out[i] = { x = unit.x + dx * i, y = unit.y + dy * i }
                end
                return out
            end,
        },
        -- No cleverness in the condition, on purpose. Whether the charge is WORTH taking is already
        -- answered by the footprint: off the line it catches nobody, and the planner drops a cast that
        -- accomplishes nothing. A `when` that restated that in subjects and tests would be a second
        -- copy of the geometry, free to drift from the first.
        ai = { priority = "high", act = "attack",
               when = { subject = "any_foe", test = "exists" } },
        effect = function(fx)
            local u = fx.user
            -- Gore first, run second. The lane's occupants are hit where the charge FINDS them, which
            -- is where the telegraph promised they would be hit; running first would gore them from
            -- wherever the rush had already shoved them to.
            for _, t in ipairs(fx.aoeUnits()) do
                if t ~= u then fx.damage(t) end
            end
            -- WHERE IT STARTED, read before anything moves it. `fx.user` is the live unit, so its x/y
            -- are rewritten by the rush below -- measuring the run against them afterwards compares the
            -- landing tile with itself, comes out zero every time, and stuns the animal on every
            -- successful charge. It did exactly that, and only the LIVE case: a dry run moves nobody, so
            -- the preview went on reporting the truth while the fight stumbled on its own feet.
            local ox, oy = u.x, u.y
            local dx, dy = step(ox, oy, fx.tx, fx.ty)
            local lx, ly = ox + dx, oy + dy
            -- ASK before running, so the forecast and the fight agree (see fx.chargeTile's note in
            -- models/combat.lua): every dry run reports 0 tiles advanced, so reading the collision off
            -- the rush's own return value would paint a stumble onto every preview.
            local rx, ry = fx.chargeTile(lx, ly, LANE)
            fx.chargeInto(lx, ly, LANE)
            -- No direction at all is the boardless grader aiming its stand-in's own origin. It has
            -- been credited the lane above; there is no collision to report about a lane that does not
            -- exist, and claiming one would grade every cast as a self-stun.
            if dx == 0 and dy == 0 then return end
            -- Stopped short: it met stone, furniture, unwalkable ground or the edge, and it met them at
            -- a dead run. Nothing on the board did this -- the player chose where to be standing.
            if math.abs(rx - ox) + math.abs(ry - oy) < LANE then
                fx.applyStatus(u, "status_stun")
            end
        end,
    },
}
