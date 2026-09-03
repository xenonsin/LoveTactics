-- Tuva's bound relic (Totemist). She puts something in the ground and it holds.
--
-- THE CENSUS IS THREE TOTEMS, and three is a very different number from two here: two totems are a
-- line, three are a SHAPE, and the shape is what the relic fills. Carved Stake and Raise Totem plant
-- them, Totem-Carver's Kit gives them the health to survive being planted, and Ley Line is the
-- connection this floods.
--
-- WHAT IT LEAVES OUTLASTS WHAT MADE IT. The ground between her totems is consecrated and stays that
-- way even after the totems fall -- which is the whole totemist argument, that a thing put in the
-- earth is more permanent than the person who put it there.
return {
    name = "The Standing Stone",
    description = "The ground between your totems is consecrated, and stays so after they fall.",
    flavor = "The totems are not the point. They are how she remembers where the point was.",
    sprite = "assets/items/sig_standing_stone.png",
    type = "utility",
    tags = { "signature", "holy" },
    class = "priest",
    discipline = "totemist",
    activeAbility = {
        target = "self",
        range = 0,
        speed = 7,
        cost = { stat = "mana", amount = 14 },
        description = "Consecrates every tile inside the shape your totems make.",
        unlock = {
            field = { of = "unit", summoned = true, count = 3,
                      test = function(u) return u.char and u.char.id == "character_totem" end },
            text = "3 totems standing",
        },
        effect = function(fx)
            -- The bounding box of the totems: the simplest honest reading of "the shape they make",
            -- and the one a player can see on the board without being told the rule.
            local minX, minY, maxX, maxY
            for _, u in ipairs((fx.combat and fx.combat.units) or {}) do
                if u.alive and u.summoner == fx.user and u.char and u.char.id == "character_totem" then
                    minX = math.min(minX or u.x, u.x); maxX = math.max(maxX or u.x, u.x)
                    minY = math.min(minY or u.y, u.y); maxY = math.max(maxY or u.y, u.y)
                end
            end
            if not minX then return end
            for y = minY, maxY do
                for x = minX, maxX do
                    fx.placeHazard(x, y, "hazard_sacred", { side = fx.user.side })
                end
            end
        end,
    },
    -- consecrated ground that stays after the totems fall
    bonus = { magicDefense = 2 },
}
