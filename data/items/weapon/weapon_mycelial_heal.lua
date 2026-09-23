-- Mycelial Heal: under the floor the mushroom folk are one body, and the Thurifer can feed it. Every
-- mushroom of its own side within three tiles is healed, itself included.
--
-- What keeps the Verger standing in front of it long enough for the Spongeflesh to matter, and the
-- second reason the Thurifer is the kill to make first. Reads the folk by blueprint (the Swooncap
-- family), so a charmed knight standing among them is not part of the mycelium and is not fed.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Mycelial Heal",
    description = "Heals every mushroom of its side within 3 tiles.",
    flavor = "What you are fighting is the part that came up. Most of it did not.",
    sprite = "assets/items/mycelial_heal.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "nature", "magical", "restorative" },
    noSteal = true,
    activeAbility = {
        target = "self",
        support = true,
        range = 0,
        speed = 5,
        cost = { stat = "mana", amount = 10 },
        ai = {
            { priority = "urgent", act = "cast",
              when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.6 } },
        },
        effect = function(fx)
            local user = fx.user
            for _, u in ipairs(fx.unitsNear(user.x, user.y, 3)) do
                if u.alive and u.side == user.side and u.char and u.char.id
                    and u.char.id:find("^character_swooncap") then
                    fx.heal(u, 6 + fx.level)
                end
            end
        end,
    },
}
