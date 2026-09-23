-- STRAND-WALK: the Larder Mother travels the web. Aimed at a foe standing on a strand or beside one --
-- ANYWHERE on the board, because Feels the Web (utility_feels_the_web) waives her range and sight
-- against exactly those bodies -- she arrives on the nearest open ground big enough for her beside them.
--
-- WAIVER-ONLY BY CONSTRUCTION: range 1 and minRange 2 admit no ordinary target at all, so the planner
-- only ever lists foes the web has handed her (Combat.abilityTargets applies the waiver to the maximum
-- range and never to the minimum). A foe beside her is one for the fangs.
--
-- IT COUNTS AS MOVING. The Still Hunt's stacks (status_still_hunt) are the price of relocating: she
-- decides whether to cash the patience she has built where she stands, or to take it somewhere else.
-- The teleport fires no enter-tile hook, so the stacks are cleared here by hand.
return {
    name = "Strand-walk",
    description = "Travels to open ground beside a foe on or beside Web, at any distance. Clears the Still Hunt.",
    flavor = "Every strand in the glade is one road, and she knows which end of it you are standing on.",
    sprite = "assets/items/ability_strand_walk.png",
    type = "ability",
    class = "creature",
    tags = { "silk" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        minRange = 2,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            local t, me = fx.target, fx.user
            if not (t and me and fx.combat) then return end
            local Combat = require("models.combat")
            if not Combat.besideWeb(fx.combat, t) then return end
            local x, y = Combat.openBlockNear(fx.combat, t.x, t.y, me.w or 1, me.h or 1, { ignore = me })
            if not x then return end
            fx.teleportUser(x, y, { glide = true })
            local Status = require("models.status")
            local held = Status.get(me, "status_still_hunt")
            if held then held.magnitude = 0 end
        end,
    },
}
