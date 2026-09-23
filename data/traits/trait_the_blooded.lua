-- THE BLOODED: she does not arrive alone. The bodies standing with her are people, and they are hers
-- before the first turn is taken.
--
-- WHAT THEY ARE, IN THE FICTION, AND IT IS ALREADY WRITTEN DOWN. The Cathedral bloods every soldier it
-- anoints, and the blood in the anointed is Luxuria's -- "she has seeded the whole order as a sleeper
-- army" (data/characters/character_general_lust.lua). This line is what that looks like at a rung a
-- company can actually reach: a succubus walks a Lust floor with two or three of the church's own
-- standing behind her, in their own plate, with their own kit, answering to her.
--
-- IT IS A REAL CHARM AND NOT A FLAG, AND THAT IS THE WHOLE POINT. The thralls carry `status_charm`
-- with her stamped as its `charmer`, applied at the bell -- which means every rule in the game that
-- reads a charmed body reads these for free and on the opening turn: her Congregation splits wounds
-- across them (data/traits/trait_the_congregation.lua), her Borrowed Blood drinks off what they do
-- (trait_borrowed_blood), Cure and Panacea free them, and Combat.releaseCharmedBy lets them go the
-- moment she falls. Nothing here is special-cased; the mechanic she is built on is simply already
-- running when the fight starts.
--
-- A BINDING RATHER THAN A TAKING, which status_charm tells apart by one fact: the charmer is already
-- on their side, so there is nothing to change hands. They stash no allegiance -- they had none left --
-- and when the binding ends they do not revert, they LEAVE (status_charm's onExpire). Cut her down and
-- most of the room walks out.
--
-- `duration = math.huge`, which survives Status.tick's countdown unchanged (huge minus elapsed is
-- huge) -- the same trick status_magic_denied and status_open_account already use for "until something
-- ends it". This one is ended by her death, by a Cure, or by the fight finishing. A ten-tick clock
-- would have the congregation wake up on turn three for no reason anybody could read.
--
-- NEAREST FIRST, AND ONLY WHAT IS UNCLAIMED. Two succubi on one board each hold their own -- the first
-- to act claims the bodies beside her, the second takes what is left -- so killing ONE of them frees
-- only hers and the other's congregation stands. That is the rule the fight wants: the room empties as
-- you work through the charmers, not all at once.
--
-- HUMANOIDS ONLY. She binds people. A harpy standing on the same floor is not a thrall, it is a
-- neighbour, and a binding that swept up the circle's own animals would make every Lust fight a fight
-- about her.
return {
    name = "The Blooded",
    description = "Opens the fight already holding nearby allied humanoids.",
    magnitude = 2, -- how many she keeps
    onCombatStart = function(ctx)
        local Status = require("models.status")
        local me = ctx.unit
        local mine = {}
        for _, u in ipairs(ctx.combat.units or {}) do
            if u.alive and u ~= me and u.side == me.side
                and u.char and u.char.kind == "humanoid"
                and not Status.get(u, "status_charm") then
                mine[#mine + 1] = u
            end
        end
        -- Stable: distance decides, and the seating order breaks a tie, so one seed binds one room.
        local order = {}
        for i, u in ipairs(mine) do order[u] = i end
        table.sort(mine, function(a, b)
            local da = math.max(math.abs(a.x - me.x), math.abs(a.y - me.y))
            local db = math.max(math.abs(b.x - me.x), math.abs(b.y - me.y))
            if da ~= db then return da < db end
            return order[a] < order[b]
        end)
        local kept = 0
        for _, u in ipairs(mine) do
            if kept >= (ctx.def.magnitude or 2) then break end
            if ctx.applyStatus(u, "status_charm", { applier = me, duration = math.huge }) then
                kept = kept + 1
            end
        end
        if kept > 0 then
            ctx.log("status", string.format("%s is holding %d of them already.",
                (me.char and me.char.name) or "She", kept), me)
        end
    end,
}
