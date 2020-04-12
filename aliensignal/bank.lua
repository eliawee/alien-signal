local Bank = require("bank")

local spritesheets = {
  "andcomparison",
  "arrow",
  "book",
  "build",
  "coupler",
  "downleftshoulder",
  "downrightshoulder",
  "input",
  "inventorybag",
  "output",
  "sampler",
  "slot",
  "upleftshoulder",
  "uprightshoulder",
  "x2booster"
}

local spec = {}

for index, name in ipairs(spritesheets) do
  spec[name] = {
    image = Bank.Asset.Image("assets/images/" .. name .. ".png"),
    spritesheet = Bank.Asset.JSON("assets/spritesheets/" .. name .. ".json")
  }
end

return Bank(spec)
