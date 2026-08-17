-- Nix's bound relic (Saboteur). She was in the room an hour ago.
--
-- SET CHARGE AND SAPPER'S LINE PLANT IT -- the Line three at a time, so the relic's size is decided by
-- how much she laid rather than by anything here. Ghost Kit and Detonator are the small triggers that
-- teach the verb; this is the one that does not have to be near any of them.
--
-- WHAT SEPARATES IT FROM THE BOMBARDIER'S SHORT FUSE, since both set off what their bearer planted:
-- Pol's is a chain -- everything goes at once and that is the whole event. Hers leaves the ROOM
-- changed: every blast pulls down what it was set against, so where the charges were is rubble
-- afterwards. A bombardier is having a moment; a saboteur is removing a building.
return {
    name = "The Signal",
    description = "Every charge you planted goes off, and the ground each stood on is left in ruins.",
    flavor = "The signal is not for the charges. They were never going to change their minds.",
    sprite = "assets/items/sig_the_signal.png",
    type = "utility",
    tags = { "signature", "impact" },
    class = "rogue",
    discipline = "saboteur",
    bound = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        description = "Detonates your charges and leaves the ground they stood on ruined.",
        unlock = { event = "cast", count = 3, text = "Cast 3 times" },
        effect = function(fx)
            -- Where they were, taken before firing: detonation clears the entries, so the rubble has
            -- to be sited from a snapshot or it lands on an empty list.
            local sites = {}
            for _, t in ipairs((fx.combat and fx.combat.traps) or {}) do
                if t.alive and t.placer == fx.user then
                    sites[#sites + 1] = { x = t.x, y = t.y }
                end
            end
            fx.detonate()
            for _, at in ipairs(sites) do
                fx.placeHazard(at.x, at.y, "hazard_quicksand", { side = fx.user.side })
            end
        end,
    },
}
