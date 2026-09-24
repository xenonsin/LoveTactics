-- COIL: the Chimera's serpent head, whose whole kit this is (character_chimera_serpent). The serpent does
-- not strike on its turn -- it gathers itself on the body it grows from (status_tail_poised), and until it
-- comes round again the first foe to strike that body in melee is bitten and Poisoned
-- (trait_serpents_strike). Its card on the strip is the tail's clock: just after it passes, the tail is
-- up; just before it comes round, the tail may already have struck.
--
-- AND IT JUDGES ITS OWN HUNGER, because the serpent always acts. A coil laid on a body still holding the
-- last one is a coil that went unused -- nothing came close -- and that feeds the head a stack of
-- status_starving; the bite eats them off (trait_serpents_strike).
return {
    name = "Coil",
    description = "Coils on the body it grows from. Until its next turn, the first foe to strike that body in melee is bitten and poisoned.",
    flavor = "It is looking the other way. So is the other end.",
    sprite = "assets/items/ability_coil.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "beast" },
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 3,
        support = true,
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local body = fx.user and fx.user.headOf
            if not body then return end
            if fx.hasStatus(body, "status_tail_poised") then
                fx.applyStatus(fx.user, "status_starving")
            end
            fx.applyStatus(body, "status_tail_poised")
        end,
    },
}
