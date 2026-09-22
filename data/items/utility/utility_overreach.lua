-- THE OVERREACH: the spell lands harder and costs more to throw.
--
-- WAS A RUN RELIC (`relic_overreach`, uncommon tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
return {
    name = "The Overreach",
    description = "Raises magic damage by 3. Every cast costs 3 more mana.",
    flavor = "A focus ground a shade too fine, so it takes more to fill and gives more back.",
    sprite = "assets/items/overreach.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that reshapes spells and pays for them in mana.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "elementalist",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: three magic damage standing, against a surcharge that bites a long fight.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 0.90,
    unlockLevel = 12,
    bonus = { magicDamage = 3 },
    rules = { manaSurcharge = 3 },
}
