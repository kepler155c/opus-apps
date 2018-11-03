local Mobs = { }

local hostiles = {
  ancient_golem = true,
  BabySkeleton = true,
  BabyZombie = true,
  Bat = true,
  Creeper = true,
  Husk = true,
  Skeleton = true,
  Slime = true,
  Spider = true,
  Witch = true,
  Zombie = true,
  ZombieVillager = true,
}

function Mobs.getNames()
	return hostiles
end

return Mobs
