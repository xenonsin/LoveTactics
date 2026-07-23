-- Binding Grace: the priest lays a total ward against magic on an ally -- and binds their hands while
-- it holds. Nothing sorcerous touches them. They may not use a weapon.
--
-- A BUFF WITH TEETH IN IT, which this catalog did not have. Every other blessing here is a pure gift:
-- Aegis, Heroism, Blessing, the barriers -- all upside, priced only in mana and a turn. This one has a
-- real cost paid by the person receiving it, which makes casting it a question rather than a reflex.
--
-- Both halves come from statuses that already exist and already mean exactly this: Magic Denied
-- (`deniesMagic`, worn by the Skeptic's Harness) refuses the craft entirely, and Disarmed
-- (`disablesWeapon`) refuses a forged weapon. Stacking them is the whole spell, and it is a genuinely
-- different piece from either.
--
-- WHO IT IS FOR is a much narrower answer than it looks, which is the fun of it:
--
--   * A KNIGHT walking through an enemy caster's zone. They were going to tank with armor anyway, and
--     armor does nothing about magic. They lose the swing and gain the crossing.
--   * A MONK, who fights with fists -- and the bare `unarmed` fallback is exempt from the disarm gate
--     (see Status.disarmed). The Cathedral's own subclass is the one body that pays nothing for this,
--     which is a piece of class design rather than an accident.
--   * NOT the party's mage, who cannot cast under it, and not the archer, who cannot shoot.
--
-- ADJACENCY: a `censer` beside it. The Cathedral binds and looses with its own instrument.
return {
    name = "Binding Grace",
    description = "Wards an ally against all magic, and binds their hands to any weapon while it holds.",
    flavor = "The Cathedral has never regarded the second clause as a price. It regards it as the point.",
    sprite = "assets/items/ability_binding_grace.png",
    type = "ability",
    tags = { "holy", "magical" },
    class = "priest",
    price = 340,
    repRank = 3,
    activeAbility = {
        target = "ally",
        range = 4,
        speed = 3,
        cost = { stat = "mana", amount = 13 },
        support = true,
        requiresAdjacent = { tag = "censer" },
        effect = function(fx)
            local dur = 12 + fx.level
            -- Two statuses rather than one combined blueprint, deliberately: they are separately
            -- cleansable, so an ally who wants their sword back can be Cured out of the disarm and
            -- keep the ward -- or lose both. Folding them into one status would have quietly removed
            -- that decision from the player.
            fx.applyStatus(fx.target, "status_magic_denied", { duration = dur })
            fx.applyStatus(fx.target, "status_disarmed", { duration = dur })
        end,
    },
}
