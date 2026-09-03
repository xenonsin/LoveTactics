-- The Careful Sigil: the magic beside it in the 3x3 grid stops catching your own line. An area cast
-- with this next to it lands on the enemy and steps over everyone on the caster's side, the caster
-- included (Combat.castUnits, the one funnel every blast in the game reaches its victims through --
-- so one charm works on a Fireball, a Blizzard, a Meteor Storm and every future area spell without
-- any of them learning the word).
--
-- One of the five sigils; see data/items/utility/utility_distant_sigil.lua for the family.
--
-- This is the sigil that changes what a mage may DO rather than how much of it. Half the Arcanum's
-- catalogue is written with a warning in the description -- "friend and foe alike, so mind your own
-- line" (Blizzard) -- and that warning is a positioning tax the mage pays on every turn it wants to
-- cast big. The sigil does not pay the tax; it deletes it, and what the mage gets back is the ability
-- to drop a Meteor Storm on a melee that has already closed. That is worth a cell.
--
-- What it deliberately does NOT do is spare the GROUND. A careful Fireball still lays fire on every
-- tile it covers, your knight's tile included, because the sigil steers the blast and not what the
-- blast leaves behind. Ground is nobody's friend (the same rule the incense/trail/banner family
-- already runs on), and a sigil that also swept the floor would make the fire hazard meaningless.
-- Worth knowing before you drop a careful Fireball on your own front rank: they will not be burned by
-- the blast, and they will be standing in a fire.
return {
    name = "Careful Sigil",
    description = "Adjacent magic spares your own side. Though not the ground it leaves behind.",
    flavor = "The Arcanum grades third-years on it. Nobody is graded on the floor.",
    sprite = "assets/items/utility_careful_sigil.png",
    type = "utility",
    tags = { "arcane", "sigil" },
    class = "mage",
    discipline = "elementalist", -- deeper cut of the shelf: buyable only once the elementalist gate is cleared
    price = 330,
    unlockQuests = 3,
    -- "The Arcanum grades third-years on it." The aura is care aimed at your own side; the Skill is the
    -- same care aimed at the target. Worth knowing that this reaches spells at all: a family-less
    -- ability answers Item.DEFAULT_HIT of 90, so magic rolls to hit like everything else and a mage's
    -- Skill moves it (docs/accuracy.md).
    --
    -- Pride is the house whose general carries the only Skill 10 on the roster, so precision-as-
    -- superiority is the Arcanum's argument to sell rather than a borrowed one.
    bonus = { skill = 2 },
    aura = {
        appliesTo = { "ability", "weapon" },
        requiresTags = { "magical" },
        careful = true, -- the neighbour's area steps over the caster's own side
    },
}
