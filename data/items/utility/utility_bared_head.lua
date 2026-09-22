-- THE BARED HEAD: deeper pools, bought out of the body's own.
--
-- WAS A RUN RELIC (`relic_bared_head`, uncommon tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
return {
    name = "The Bared Head",
    description = "Raises maximum mana and stamina by 4 each. Lowers maximum health by 8.",
    flavor = "No helm, no hood, nothing between the wearer and the weather. The trade is stated in the name.",
    sprite = "assets/items/bared_head.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that spends mana and stamina in the same action, so both ceilings are its currency.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "battlemage",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: two ceilings raised out of a third, which is a caster's whole resource question.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    unlockLevel = 12,
    maxBonus = { mana = 4, stamina = 4, health = -8 },
}
