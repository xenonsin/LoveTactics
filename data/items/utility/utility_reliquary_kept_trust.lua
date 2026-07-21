-- Amana's signature relic (docs/story.md, "The other seven": the priest answers lust with devotion).
-- A reliquary she carries but keeps nothing from -- the build-around at the center of her loadout grid.
--
-- It carries her giving loop as a passive (data/traits/trait_sanctified_presence.lua): she and the
-- allies beside her mend a little each tick. And its own answer is the virtue stated as an unlock: it
-- does nothing until she has DONE the giving -- mended three times ("healDone", banked by any heal that
-- actually restored something, Combat.tally at fx.heal) -- and only then may it be poured out. When it
-- fires she wards the whole company around her with Aegis and Regeneration and keeps NONE of it for
-- herself (the cast spares fx.user): devotion is the gift she cannot turn inward. The conditional-
-- signature system greys it with a "Mend thrice (n/3)" badge until earned and re-locks it after each use
-- (Combat.unlockMet / itemBlockReason), exactly as the Knight's Sworn Aegis re-locks after its sweep.
--
-- She stacks the giving with an ordinary Heal in the grid (data/items/ability/ability_heal.lua): three
-- casts of mercy open the reliquary. Note the ward it lays does NOT feed itself -- Aegis and Regeneration
-- mend on the status clock (Combat.regenerate/onTick), which never routes through fx.heal, so the payoff
-- can't re-charge on its own smoke. It is the inverse of Lust's arithmetic: Luxuria takes the reserves a
-- foe withheld (data/traits/trait_rapture.lua); Amana spends her own turns handing wards away, and takes
-- nothing back.
--
-- It also carries the other half of her rule (data/traits/trait_devotion_unbidden.lua): her will cannot
-- be taken. Charm sheds off her, and Lust's Rapture finds nothing held back to seize. It rides here, on
-- the bound relic she can never be parted from, rather than on the character blueprint -- the only place a
-- trait actually attaches (models/trait.lua reads item.traits; a blueprint's own `traits` is never
-- collected), and the reason it survives her recruit-fight boss flag going inert once she is an ally.
--
-- `bound = true` (models/item.lua): never moved, stowed, given, sold, or stolen -- only forged. No
-- `price`; `class = "priest"` still tallies priest growth. Its ward against magic climbs with the forge.
return {
    name = "Reliquary of the Kept Trust",
    description = "Once you have mended thrice, ward the whole company -- and keep none of it for yourself.",
    flavor = "A trust is a thing you hold and hand back whole. She has never once opened it for herself.",
    sprite = "assets/items/sig_reliquary_kept_trust.png",
    type = "utility",
    tags = { "signature" },
    class = "priest",
    bound = true,
    traits = { "trait_sanctified_presence", "trait_devotion_unbidden" },
    bonus = { magicDefense = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } },
    activeAbility = {
        description = "Wards every nearby ally -- but not you -- with Aegis and Regeneration.",
        target = "self", -- centred on her; the aoe catches the company around her
        support = true,  -- friendly cast: preview green
        range = 1,
        speed = 6,
        cost = { stat = "mana", amount = 18 },
        unlock = { event = "healDone", count = 3, text = "Mend thrice" },
        aoe = { radius = 3, shape = "square" },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                -- Every ally but herself: the gift she cannot turn inward.
                if u.side == fx.user.side and u ~= fx.user then
                    fx.applyStatus(u, "status_aegis")
                    fx.applyStatus(u, "status_regen")
                end
            end
        end,
    },
}
