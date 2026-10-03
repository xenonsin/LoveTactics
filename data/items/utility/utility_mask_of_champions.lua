-- MASK OF CHAMPIONS: the Faceless Champion's drop (data/characters/character_faceless_champion.lua), its hand of
-- champions worn small. Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2).
--
-- Three reflexes carried and one worn (data/traits/trait_mask_of_champions.lua): the Bladedancer's Untouchable,
-- the Pit-Fighter's Challenge, the Griffin's Answers Every Blow. It opens wearing Untouchable; the button swaps to
-- the next in that order, and it is a free action, so it is once a turn and costs the turn nothing. The badge on
-- the bearer is the readout. An unstocked trophy on the seat's rung.
return {
    name = "Mask of Champions",
    description = "Carry three champions' reflexes: Untouchable, the Challenge, Answers Every Blow. Swap which one you wear once a turn.",
    flavor = "Each face on it beat somebody once. Together they have never lost, which is not the same as winning.",
    sprite = "assets/items/utility_mask_of_champions.png",
    type = "utility",
    tags = { "guile" },
    class = "duelist",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_mask_of_champions" },
    activeAbility = {
        target = "self",
        range = 0,
        speed = 0,
        free = true, -- one free action a turn: the swap is the "once a turn"
        support = true,
        effect = function(fx)
            local SF = require("models.stolen_faces")
            if not fx.user then return end
            local nextId = SF.nextReflex(fx.user)
            for _, id in ipairs(SF.REFLEXES) do
                if id ~= nextId and fx.hasStatus(fx.user, id) then fx.clearStatus(fx.user, id) end
            end
            local st = fx.applyStatus(fx.user, nextId, { applier = fx.user })
            if st and nextId == "status_the_challenge" and fx.combat then
                SF.nameChallenger(fx.combat, fx.user)
            end
        end,
    },
}
