------------------------------------------------------------------------------------------
-- ORE3D - Fully Immersive Augmented Reality X-RAY Vision for Ore Mining using Plethora --
------------------------------------------------------------------------------------------

-- CREATED BY:
--   HydroNitrogen (a.k.a. GoogleTech, Wendelstein7)
--   Bram S. (a.k.a ThatBram0101, bram0101)

-- LICENCE: ZLIB/libpng Licence (Zlib) (MODIFIED)
--   Copyright (c) 2018 HydroNitrogen & Bram S.
--   This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
--   Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
--   1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
--   2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
--   3. Every version, altered and original, must always contain a link to the following internet page: https://energetic.pw/computercraft/ore3d
--   4. This notice may not be removed or altered from any source distribution.

-- VERSION 2018-03-29 15:52 (Dates are way easier than version numbers, :P )


local FOV          = math.rad(70) -- Change according to your Minecraft settings! Minecraft default: 75
local ASPECT_RATIO = 1.8 -- Aspect ratio of your view - for a full HD screen: fullscreen: 1.7777, windowed: 1.8
local hintToBehind = true -- Show all blocks behind you on the sides of your screen
local CHAR_SIZE    = 16 -- the base size of the indicators

local SCRHOR = (1 / math.tan(FOV / 2)) / ASPECT_RATIO
local SCRVER = (1 / math.tan(FOV / 2))

-- Convert to perspective projection, removes a dimention (z)  (optimized, uses precalculated values)
local function toPerspective(x, y, z)
  return SCRHOR * x / z, SCRVER * y / z
end

local function getCharSize(d) -- Calculates size of indicators using distance
  return CHAR_SIZE / d
end

local Project = { }

function Project:init(canvas)
  self.canvas = canvas
  self.cx, self.cy = canvas.getSize()
  self.cxhalf = self.cx / 2
  self.cyhalf = self.cy / 2
end

function Project:ndcToSpc(x, y)
  return x * self.cxhalf + self.cxhalf, y * self.cyhalf + self.cyhalf
end

function Project:isOnScreen(x, y, d) -- determines if something is visible
  return (x >= 1 and x - getCharSize(d) < self.cx) and (y >= 1 and y - getCharSize(d) < self.cy)
end

function Project:draw(meta, b, text, color)
  local yaw = math.rad(meta.yaw)
  local pitch = math.rad(meta.pitch)

  local ysin = math.sin(yaw)
  local ycos = math.cos(yaw)

  local psin = math.sin(pitch)
  local pcos = math.cos(pitch)

  local function rotate(x, y, z) -- Matrix operation: rotate (optimized, uses precalculated values)
    local newx = ycos * x + ysin * z
    local newz = -ysin * x + ycos * z

    local newy = pcos * y - psin * newz
    newz = psin * y + pcos * newz

    return newx,newy,newz
  end

  local x,y,z = rotate(b.x - meta.x, -b.y + meta.y, b.z - meta.z)
  local d = math.sqrt(x * x + y * y + z * z)

  if hintToBehind and z < 0 then z = 0.001 end

  if z >= 0 or hintToBehind then -- render only if point is visible OR hintToBehind is enabled
    x,y = toPerspective(x, y, -z)
    x,y = self:ndcToSpc(x, y)

    if hintToBehind or self:isOnScreen(x, y, d) then
      x = math.min(math.max(x, 1), self.cx - 10 * getCharSize(d))
      y = math.min(math.max(self.cy - y, 1), self.cy - 10 * getCharSize(d))

      self.canvas.addDot({ x, y }, color, 32 / d)
    end
  end
end

return Project
