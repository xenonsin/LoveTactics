-- A wand, so it reaches at range and needs only a direction (docs/weapons.md). Its extra is that it pays
-- somebody else's wind-up: the bolt grants an ally status_second_utterance, and their next channelled
-- working resolves AT ONCE, with no draw at all.
--
-- Quest-only: `class` with no `price`.
--
-- Every channelled thing in this game is priced the same way and the price is always the same objection:
-- you commit a turn, the enemy gets to see it, and they walk out of the aimed tile or break the channel
-- outright. That objection is what a greatsword, a longbow and half the Arcanum's spell list all pay, and
-- nothing in the catalog has ever been able to answer it.
--
-- So this is the party's answer, and it is deliberately handed to somebody else rather than kept. A mage
-- carrying it can hand a greatswordsman an unbreakable, untelegraphed Avalanche, or let an archer loose a
-- Knell-Shaft the turn they decide to. Read against data/items/weapon/weapon_kingsfall.lua, which solves
-- the same problem for one weapon by refusing interruption: that one makes the telegraph survivable, this
-- one deletes it.
--
-- Its own bolt is feeble, and the gift lands on a friend rather than the target -- so a mage swinging
-- this at nothing is a mage who wasted a turn. It needs a channelled weapon in the party to mean
-- anything at all.
return {
    name = "Wand of the Second Utterance",
    description = "A bolt at range that lets one ally's next channelled working resolve instantly, with no wind-up.",
    flavor = "Saying it once was always enough. The Arcanum spent four hundred years finding out who had to say it.",
    sprite = "assets/items/second_utterance_wand.png",
    type = "weapon",
    tags = { "wand", "magical", "arcane", "ranged" },
    class = "mage",
    activeAbility = {
        target = "ally",
        range = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "mana", amount = 9 },
        damage = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }, -- the gift is the cast
        effect = function(fx)
            local t = fx.target
            if not t or not t.alive then return end
            fx.applyStatus(t, "status_second_utterance", { duration = 12 + 2 * fx.level })
            fx.log("action", string.format("%s speaks for %s.",
                (fx.user.char and fx.user.char.name) or "Unit",
                (t.char and t.char.name) or "an ally"))
        end,
    },
}
