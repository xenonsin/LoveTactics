-- WHAT EACH CLASS ASKS A BODY TO HAVE DONE before a Charter Seal will make it theirs (Class.canUnlock).
--
-- One row per class: `deed` names a per-body counter (char.deeds[deed], banked from Combat.tally on a
-- won fight -- Class.bankDeeds), `count` is how many, and `label` is the line the Classes tab prints.
-- A deed counts whatever class the body is standing in when it does it.
--
-- The seven ROOTS and the seventeen SUBCLASSES carry one each. Crossings carry none: their gate is both
-- parents' levels plus a subclass unlocked from each (Class.levelGateMet), and that is deed enough.
-- Novice carries none either -- every body holds it.
--
-- The deed keys are Combat.tally event names, so a counter here is the same fact the fight already
-- counts (see the vocabulary block above Combat.tally in models/combat.lua).
return {
    -- Roots: Novice 1 + the deed + a seal.
    fighter   = { deed = "killMelee",     count = 15,  label = "Fell 15 foes with melee blows" },
    knight    = { deed = "tauntDrawn",    count = 10,  label = "Draw 10 attacks with a taunt" },
    priest    = { deed = "healGiven",     count = 300, label = "Restore 300 HP to allies" },
    rogue     = { deed = "hitControlled", count = 10,  label = "Land 10 hits on Stunned or Rooted foes" },
    mage      = { deed = "killSpell",     count = 10,  label = "Fell 10 foes with spells" },
    hunter    = { deed = "killRanged",    count = 10,  label = "Fell 10 foes from 3 or more tiles away" },
    alchemist = { deed = "consumed",      count = 15,  label = "Use 15 consumables" },

    -- Subclasses: the parent's level (`requires`) + the deed + a seal.
    warlord      = { deed = "killFlanked",   count = 10,  label = "Fell 10 foes with 2 or more allies beside you" },
    barbarian    = { deed = "killWounded",   count = 5,   label = "Fell 5 foes while below half health" },
    bulwark      = { deed = "slammed",       count = 10,  label = "Knock 10 foes into a wall or a body" },
    sentinel     = { deed = "guarded",       count = 10,  label = "Take 10 blows meant for an ally" },
    thief        = { deed = "disarmApplied", count = 8,   label = "Disarm 8 foes" },
    assassin     = { deed = "killExecute",   count = 10,  label = "Fell 10 foes that were below a quarter health" },
    mammonite    = { deed = "goldEarned",    count = 300, label = "Earn 300 gold in fights" },
    exorcist     = { deed = "killUndead",    count = 15,  label = "Fell 15 undead" },
    monk         = { deed = "unarmedHit",    count = 30,  label = "Land 30 unarmed blows" },
    elementalist = { deed = "weaknessHit",   count = 15,  label = "Strike 15 weaknesses" },
    necromancer  = { deed = "revived",       count = 15,  label = "Revive allies 15 times" },
    summoner     = { deed = "summoned",      count = 10,  label = "Cast 10 summons" },
    beastmaster  = { deed = "charmBeast",    count = 10,  label = "Charm 10 beasts" },
    druid        = { deed = "healBeast",     count = 10,  label = "Heal a beast on your side 10 times" },
    trapper      = { deed = "rootApplied",   count = 10,  label = "Root 10 foes" },
    bombardier   = { deed = "areaTriple",    count = 5,   label = "Catch 3 or more foes in one area, 5 times" },
    poisoner     = { deed = "poisonApplied", count = 20,  label = "Poison foes 20 times" },
}
