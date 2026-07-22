-- Ren's signature relic (docs/story.md, "The Crucible": the alchemist answers envy with kindness). The
-- alchemists' aqua vitae -- the water of life -- and her whole character in one item: she makes the base
-- noble by spending herself to lift others, and keeps nothing.
--
-- It is the clean mechanical inversion of the Envious Glass (data/items/utility/utility_envious_glass.lua):
-- the general copies your strongest onto HERSELF; Ren copies your strongest onto your OWN side, a gift,
-- keeping nothing for herself. Envy levels down; kindness levels up; same engine call (Summon.copyOf via
-- fx.copyOf), opposite beneficiary. Fielded upward, it flattens the party into the high, self-sufficient
-- plateau that gives Covetous Reflection nothing tall enough to be worth coveting.
--
-- Its answer is a conditional-unlock signature (per the system on Rowan's Sworn Aegis and Kaya's Wolfsong
-- Horn): it charges on a GIVEN tally -- the healing she has poured into allies ("healDone", banked by
-- Combat.useItem) -- and only once she has given three times may she transmute. The signature system greys
-- it with a "Given (n/3)" badge until earned, and the copyOf claim holds the item while the gift still
-- stands: one gift at a time (Combat.itemBlockReason).
--
-- TODO (see docs/story.md): its SECOND form, earned at slot 8 -- the giver lets herself be gilded in
-- return, the one who only ever gave finally receiving -- is deferred new work.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. No `price`;
-- `class = "alchemist"` still tallies alchemist growth.
return {
    name = "Aqua Vitae",
    description = "Give three times, then grant the party a copy of your strongest -- a gift, kept for no one.",
    flavor = "The water of life. She has poured out a great deal of it, and asked for none back.",
    sprite = "assets/items/sig_aqua_vitae.png",
    type = "utility",
    tags = { "signature", "arcane" },
    class = "alchemist",
    bound = true,
    bonus = { magicDamage = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } },
    activeAbility = {
        description = "Conjures a copy of your strongest ally, fighting at your side. It is not fragile.",
        target = "self",
        range = 1,
        speed = 6,
        cost = { stat = "mana", amount = 20 },
        unlock = { event = "healDone", count = 3, text = "Given" },
        effect = function(fx)
            -- The one that towers on your OWN side (Ren may lift herself, but usually another): a gift of
            -- the party's best, granted to the party. Copies of copies are skipped.
            local best, bestScore
            for _, u in ipairs(fx.combat.units) do
                if u.alive and u.side == fx.user.side and not u.summoned then
                    local s = u.char.stats
                    local score = (s.health and s.health.current or 0) + (s.damage or 0) + (s.magicDamage or 0)
                    if not bestScore or score > bestScore then best, bestScore = u, score end
                end
            end
            if not best then return end
            local x, y = fx.openTileNear(fx.user.x, fx.user.y)
            if not x then
                fx.log("system", string.format("%s has no room to set the gift down.", fx.user.char.name or "Unit"))
                return
            end
            fx.copyOf(best, x, y) -- not fragile: the finished Work, granted away
        end,
    },
}
