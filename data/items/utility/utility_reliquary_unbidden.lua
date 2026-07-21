-- Lifted off Luxuria's body, and it kept her rule (data/traits/trait_rapture.lua): carry it and you take
-- the reserves your foes hold back, and become the thing you killed -- the shape every one of the seven
-- relics takes, kill a sin and wear it (compare data/items/armor/armor_mail_of_the_unappeased.lua).
--
-- It is a trap dressed as a reward, as it was on her: it feeds on other people withholding, and it makes
-- withholding your own habit. The one hand it can never draw from is a party that spends freely -- which
-- is precisely the habit it quietly trains out of you.
--
-- No `class`, no `price`, `noSteal`: there is one, and nothing takes it off you. The FLAVOR carries this
-- general's fragment of the Gate Below's location (docs/item-text.md: story, not a rule; the tooltip
-- prints it italic at the foot). The Gate is keyed off the QUEST finished, never off this item (questGate
-- in models/quest.lua), so stashing it, wearing it, or losing it can never cost the endgame.
return {
    name = "Reliquary of the Unbidden",
    description = "Draws off the stamina and mana your foes held back, and takes it into you as health.",
    flavor = "Luxuria's reliquary, still smoking. Etched round the base: \"under the nave, where the " ..
        "faithful were unmade and the choir sang over it\".",
    sprite = "assets/items/reliquary_unbidden.png",
    type = "utility",
    tags = { "relic" },
    noSteal = true, -- nothing takes this off you; you took it off her
    traits = { "trait_rapture" },
    bonus = { magicDefense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
}
