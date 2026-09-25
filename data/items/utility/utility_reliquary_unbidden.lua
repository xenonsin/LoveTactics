-- Lifted off Luxuria's body, and it kept her rule -- the new one (data/traits/trait_her_court.lua): her
-- strength was the army standing around her, and carried, it is yours, a tenth again of your damage and
-- defense for every foe you hold. The shape every one of the seven relics takes -- kill a sin and wear it
-- (compare data/items/armor/armor_mail_of_the_unappeased.lua).
--
-- REWORKED ON REVIEW 2026-09-25, when Luxuria became the Queen of the succubi. It carried Rapture --
-- drinking the stamina and mana a foe held back -- which was her old rule, and it goes with it: the
-- Saint's Chalice (utility_saints_chalice) carries that now, reworked as a drain on everything around the
-- body you hit. The relic pairs with what her own line drops -- Charm, and the Congregation -- so the set
-- is assembled out of one circle.
--
-- No `price`, `noSteal`: there is one, and nothing takes it off you. The FLAVOR carries this general's
-- fragment of the Gate Below's location (docs/item-text.md: story, not a rule; the tooltip prints it italic
-- at the foot). The Gate is keyed off the QUEST finished, never off this item (questGate in
-- models/quest.lua), so stashing it, wearing it, or losing it can never cost the endgame.
local Curve = require("models.curve")

return {
    name = "Reliquary of the Unbidden",
    description = "+10% damage and defense for each foe you currently have Charmed.",
    flavor = "Luxuria's reliquary, still smoking. Etched round the base: \"under the nave, where the " ..
        "faithful were unmade and the choir sang over it\".",
    sprite = "assets/items/reliquary_unbidden.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_her_court" },
    bonus = { magicDefense = Curve.ramp(3, 13) },
}
