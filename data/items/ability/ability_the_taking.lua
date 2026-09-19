-- THE TAKING: everything of his lying on that ground gets up again.
--
-- The second half's whole idea, and the reason the first half's correct play is the thing that arms it.
-- You spend the fight killing the clan because the clan is what touches you (ability_the_call). Then he
-- turns, and every body you made is his to stand back up.
--
-- TWO ROUTES, ONE SENTENCE. A fallen boar is in one of two states and the engine treats them as
-- different things entirely (models/combat.lua's corpse section), so this reaches both:
--
--   DOWNED    -- still inside its revive window. fx.reanimate stands the SAME animal back up on its own
--                side at half its ceiling, statuses wiped. It keeps its id, its kit and its bound
--                traits -- including the Curse-Bearer the Call tied to it -- because the unit never
--                left the field, so it will leave curse on the floor all over again when it drops.
--   COLD      -- past reviving, a harvestable corpse. The body is spent outright and a fresh boar takes
--                its place on his side, carrying the same bargain the Call strikes.
--
-- The player does not need to know there are two routes. What they see is that the dead get up, and
-- that there is no way to kill a boar safely -- which is the correct reading, since both routes end in
-- the same animal standing on the same tile.
--
-- WHY IT IS SPENT AND RE-SUMMONED RATHER THAN RAISED. Combat.raiseZombie is the obvious call and it is
-- the wrong one here by one detail: its opts forward duration/amount/scaling and NOT `traits`, so a boar
-- raised through it would arrive without the Curse-Bearer and would die leaving clean ground. Consuming
-- the corpse and calling the body directly is the same two operations raiseZombie performs, with the
-- bargain attached -- so a taken boar is indistinguishable from a called one, which is the promise the
-- fiction makes.
--
-- SELF-CENTRED, radius 2. The bodies are where the fighting was, so this makes him WALK to his dead --
-- which is the counterplay stated as geometry: fight away from your kills, and make him come off them.
-- It is also why character_the_turning is the agile half of this animal. A lord who could take the whole
-- board from where he stood would need no legs and the player would need no plan.
--
-- The lists are gathered BEFORE anything is raised. Standing a body up puts a living unit on the tile,
-- and Combat.corpseAt refuses a tile someone is standing on -- so sweeping and raising in one pass would
-- have each arrival hide the next body along.
return {
    name = "The Taking",
    description = "Stands every fallen boar within two tiles back up, dying or dead.",
    flavor = "It does not distinguish between the two. Neither, in the end, does the ground.",
    sprite = "assets/items/ability_the_taking.png",
    type = "ability",
    tags = { "dark", "summon" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        support = true, -- his own dead: preview green, and the planner offers it allied marks
        cost = { stat = "stamina", amount = 8 },
        aoe = { radius = 2, shape = "square" },
        ai = { priority = "high", act = "support",
               when = { subject = "any_ally", test = "count_at_most", value = 4 } },
        effect = function(fx)
            -- Gather first, act second (see the header): a raised body hides the next corpse along.
            local cold, downed = {}, {}
            for _, c in ipairs(fx.aoeCells()) do
                local corpse = fx.corpseAt(c.x, c.y)
                if corpse then cold[#cold + 1] = corpse end
                local body = fx.downedAt(c.x, c.y)
                if body then downed[#downed + 1] = body end
            end
            -- The dying, stood back up as themselves. Half a ceiling, which is what makes taking a
            -- body twice worth less than taking it once and is the only brake this needs.
            for _, body in ipairs(downed) do
                fx.reanimate(body, 0.5)
            end
            -- The dead, spent for a fresh one on the same tile, carrying the same bargain.
            for _, corpse in ipairs(cold) do
                local x, y = corpse.x, corpse.y
                if fx.consumeCorpse(corpse) then
                    fx.summon("character_boar", x, y, {
                        traits = { "trait_curse_bearer" },
                        noClaim = true,
                    })
                end
            end
        end,
    },
}
