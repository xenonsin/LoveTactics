-- Recall Construct: the mage half of the Artificer (mage x alchemist). Takes a standing construct off
-- the field, hands back half the mana that raised it, and lets you set it down somewhere else.
--
-- It answers the first of the three things actually wrong with turrets, which is that they are in the
-- wrong place. An Ordnance Sentry cannot move at all -- that is the whole bargain of it -- so an
-- artificer who emplaced one two turns ago is fighting the battle they predicted rather than the one
-- they are in. An emplacement you can pick up is a different unit from one you cannot.
--
-- Half the cost back rather than all of it: recalling is a correction, and a correction should cost
-- something or the emplacement decision stops being a decision.
--
-- It also frees the item's `activeSummon` claim (Combat.dismiss unwinds it), so the Emplace Sentry that
-- called it can be cast again -- which is really what "redeploy" means here. The construct is not
-- carried; it is unmade and rebuilt, and it comes back at full health because it was never damaged, it
-- was disassembled.
return {
    name = "Recall Construct",
    description = "Dismisses one of your constructs, refunds half its mana, and lets you rebuild it in range.",
    flavor = "It is not a retreat. It is a revision.",
    sprite = "assets/items/ability_recall_construct.png",
    type = "ability",
    tags = { "utility" },
    class = "mage",
    discipline = "artificer",
    price = 260,
    unlockQuests = 3,
    activeAbility = {
        target = "tile",
        range = 3,
        speed = 3,
        cost = { stat = "mana", amount = 4 },
        description = "Unmakes a construct of yours and rebuilds it on the aimed tile.",
        effect = function(fx)
            -- The bearer's own constructs only. A summon is `summoned` and knows its summoner; an
            -- artificer does not get to pick up somebody else's work.
            local found
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.summoned and u.summoner == fx.user and not u.decoyOf then
                    found = u
                    break
                end
            end
            if not found then
                fx.log("action", "There is nothing of yours standing to recall.")
                return
            end
            local charId = found.char and found.char.id
            -- Preserve how the recalled thing was run: a construct is autonomous (control = "ai"), and a
            -- revision of it must not quietly become yours to steer by inheriting the caster's control.
            local control = found.control
            fx.restore(fx.user, "mana", 6 + fx.level)
            fx.dismiss(found)
            if charId then
                fx.summon(charId, fx.tx, fx.ty, { scaling = { health = 1 }, noClaim = true, control = control })
            end
        end,
    },
}
