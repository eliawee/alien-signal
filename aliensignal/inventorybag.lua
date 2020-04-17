local bank = require("aliensignal.bank")
local peachy = require("peachy")
local Color = require("aliensignal.color")
local Event = require("event")
local Object = require("classic")
local Module = require("aliensignal.module")

local InventoryBag = Object:extend()

InventoryBag.Margin = 32
InventoryBag.Border = 4
InventoryBag.ColsCount = 6
InventoryBag.ColsMargin = 64
InventoryBag.ItemSize = 128
InventoryBag.TabsIndexes = {
  modules = 1,
  junk = 2,
  build = 3,
  signal = 4
}

InventoryBag.Heights = {
  modules = 256,
  junk = 256,
  build = 640,
  signal = 640
}

InventoryBag.InventoryIndexes = {
  modules = true,
  junk = true,
  build = false,
  signal = false
}

InventoryBag.CraftIndexes = {
  modules = false,
  junk = false,
  build = true,
  signal = true
}

InventoryBag.Slot = Object:extend()

function InventoryBag.Slot:new(item, index, bag)
  self.bag = bag
  self.index = index
  self.name = item.name
  self.items = {item}
  self.text = love.graphics.newText(InventoryBag.Font, "1")
  self.countTransform = love.math.newTransform()
  self.onDrop = Event()

  self:initItemPosition(item)
  self.countTransform:translate(item.position.x + 127, item.position.y + 127)
end

function InventoryBag.Slot:initItemPosition(item)
  local col = (self.index - 1) % InventoryBag.ColsCount + 1
  local row = math.floor((self.index - 1) / InventoryBag.ColsCount)

  item.position = {
    x = col * InventoryBag.ItemSize,
    y = 768 + row * InventoryBag.ItemSize
  }
end

function InventoryBag.Slot:add(item)
  if item.name == self.name then
    table.insert(self.items, item)
    self:initItemPosition(item)
    return true
  end

  return false
end

function InventoryBag.Slot:update(dt)
  for index, item in pairs(self.items) do
    item:update(dt)
  end

  if self.movingItem then
    self.movingItem:update(dt)
  end

  self.text:set(tostring(table.getn(self.items)))
end

function InventoryBag.Slot:mousemoved(x, y, dx, dy)
  if self.movingItem then
    self.movingItem.position.x = self.movingItem.position.x + dx
    self.movingItem.position.y = self.movingItem.position.y + dy
  end
end

function InventoryBag.Slot:mousereleased(x, y, button, istouch)
  if self.movingItem then
    self.onDrop:trigger({item = self.movingItem, x = x, y = y})
    self.movingItem = nil
  end
end

function InventoryBag.Slot:mousepressed(x, y, button)
  local item = self.items[table.getn(self.items)]

  if
    item and x > item.position.x and x < item.position.x + InventoryBag.ItemSize and
      y > item.position.y - InventoryBag.Heights[self.bag.activeTab] and
      y < item.position.y - InventoryBag.Heights[self.bag.activeTab] + InventoryBag.ItemSize
   then
    self.movingItem = table.remove(self.items, table.getn(self.items))
    return true
  end
end

function InventoryBag.Slot:draw()
  for index, item in pairs(self.items) do
    item:draw()
  end

  if self.movingItem then
    self.movingItem:draw()
  end

  love.graphics.push()
  love.graphics.applyTransform(self.countTransform)
  love.graphics.polygon("fill", -8, -4, -40, -4, -44, -8, -44, -16, -40, -20, -8, -20, -4, -16, -4, -8)
  Color.Black:use()
  love.graphics.draw(self.text, -44 + (36 - self.text:getWidth()) / 2, -20)
  love.graphics.setColor(1, 1, 1, 0.5)

  love.graphics.rectangle(
    "line",
    -InventoryBag.ItemSize + 1,
    -InventoryBag.ItemSize + 1,
    InventoryBag.ItemSize,
    InventoryBag.ItemSize
  )

  Color.White:use()
  love.graphics.pop()
end

function InventoryBag.Load()
  InventoryBag.Shader =
    love.graphics.newShader(
    [[
    #define COLOR1 vec4(217.0 / 256.0, 160.0 / 256.0, 102.0 / 256.0, 1)
    #define COLOR2 vec4(238.0 / 256.0, 195.0 / 256.0, 154.0 / 256.0, 1)

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
      return mix(COLOR1, COLOR2, 1 - abs(mod(floor(screen_coords.x / 128), 2) - mod(floor(screen_coords.y / 128), 2)));
    }
  ]]
  )

  InventoryBag.Font = love.graphics.newFont("assets/fonts/emulogic.ttf", 12)
end

function InventoryBag:new(navigator)
  self.sprites = {
    tabs = {
      modules = peachy.new(bank.tabs.spritesheet, bank.tabs.image, "inventorybag"),
      junk = peachy.new(bank.tabs.spritesheet, bank.tabs.image, "junk"),
      build = peachy.new(bank.tabs.spritesheet, bank.tabs.image, "build"),
      signal = peachy.new(bank.tabs.spritesheet, bank.tabs.image, "signal")
    }
  }

  self.activeTab = "modules"
  self.navigator = navigator
  self.transform = love.math.newTransform()
  self.opened = false
  self.onDrop = Event()
  self.slots = {
    modules = {},
    junk = {}
  }

  self.inventory = {
    modules = {},
    junk = {}
  }
  self.position = {
    x = InventoryBag.Margin,
    y = 768 - self.sprites.tabs.modules:getHeight() * 4 + InventoryBag.Border
  }
end

function InventoryBag:fill(inventory)
  self.inventory = inventory
end

function InventoryBag:prepareSlots()
  self:prepareStorageSlots("junk")
  self:prepareStorageSlots("modules")
end

function InventoryBag:prepareStorageSlots(storage)
  self.slots[storage] = {}

  for index, item in ipairs(self.inventory[storage]) do
    local itemAdded = false

    for slotIndex, slot in ipairs(self.slots[storage]) do
      if slot:add(item) then
        itemAdded = true
        break
      end
    end

    if not itemAdded then
      local newSlot = InventoryBag.Slot(item, table.getn(self.slots[storage]) + 1, self)

      newSlot.onDrop:subscribe(
        function(data)
          self.onDrop:trigger(data)
        end
      )

      table.insert(self.slots[storage], newSlot)
    end
  end
end

function InventoryBag:pop(itemToPop)
  local newInventory = {}
  local storage = itemToPop:is(Module) and "modules" or "junk"

  for index, item in pairs(self.inventory[storage]) do
    if not (item == itemToPop) then
      table.insert(newInventory, item)
    end
  end

  self.inventory[storage] = newInventory
end

function InventoryBag:store(item)
  for index, slot in pairs(self.slots.modules) do
    if slot:add(item) then
      break
    end
  end
end

function InventoryBag:open()
  self.transform:reset()
  self.transform:translate(0, -InventoryBag.Heights[self.activeTab])

  if not self.opened then
    self:prepareSlots()
    self.opened = true
  end
end

function InventoryBag:close()
  if self.opened then
    self.transform:translate(0, InventoryBag.Heights[self.activeTab])
    self.opened = false
  end
end

function InventoryBag:mousemoved(x, y, dx, dy)
  if self.opened then
    for index, slot in pairs(self.slots.modules) do
      slot:mousemoved(x, y, dx, dy)
    end
  end
end

function InventoryBag:tabPressed(x, y, button, name)
  local xOffset = (InventoryBag.TabsIndexes[name] - 1) * (self.sprites.tabs.modules:getWidth() + 1) * 4
  local yOffset = self.opened and -InventoryBag.Heights[self.activeTab] or 0

  return button == 1 and x >= self.position.x + xOffset and
    x <= self.position.x + self.sprites.tabs.modules:getWidth() * 4 + xOffset and
    y >= self.position.y + yOffset and
    y <= self.position.y + yOffset + self.sprites.tabs.modules:getHeight() * 4
end

function InventoryBag:mousepressed(x, y, button)
  if self:tabPressed(x, y, button, "modules") then
    self.activeTab = "modules"
    self:open()
    return true
  elseif self:tabPressed(x, y, button, "junk") then
    self.activeTab = "junk"
    self:open()
    return true
  elseif self:tabPressed(x, y, button, "build") then
    self.activeTab = "build"
    self:open()
    return true
  elseif self:tabPressed(x, y, button, "signal") then
    self.activeTab = "signal"
    self:open()
    return true
  elseif
    self.opened and x < InventoryBag.Margin or
      x > self.position.x + InventoryBag.Margin + 1024 - InventoryBag.Margin * 2 or
      y < 768 - InventoryBag.Heights[self.activeTab]
   then
    self:close()
  elseif self.opened and self.activeTab == "modules" then
    for index, slot in pairs(self.slots.modules) do
      if slot:mousepressed(x, y, button) then
        break
      end
    end
    return true
  end
end

function InventoryBag:mousereleased(x, y, button, istouch)
  if self.opened then
    for index, slot in pairs(self.slots.modules) do
      slot:mousereleased(x, y, button, istouch)
    end
  end
end

function InventoryBag:update(dt)
  for index, sprite in pairs(self.sprites.tabs) do
    sprite:update(dt)
  end

  if InventoryBag.InventoryIndexes[self.activeTab] then
    for index, slot in pairs(self.slots[self.activeTab]) do
      slot:update(dt)
    end
  end
end

function InventoryBag:drawInventoryPanel(slots)
  Color.White:use()
  love.graphics.setShader(InventoryBag.Shader)
  love.graphics.rectangle(
    "fill",
    self.position.x + InventoryBag.Border,
    self.position.y + self.sprites.tabs.modules:getHeight() * 4,
    1024 - InventoryBag.Margin * 2 - InventoryBag.Border * 2,
    768
  )
  love.graphics.setShader()

  for index, slot in pairs(slots) do
    slot:draw()
  end
end

function InventoryBag:drawCraftPanel()
  local fullWidth = 1024 - InventoryBag.Margin * 2
  local fullHeight = InventoryBag.Heights[self.activeTab]
  local leftWidth = math.floor(fullWidth / 3)
  local rightWidth = fullWidth - leftWidth
  local topHeight = math.floor(fullHeight / 3)
  local downHeight = fullHeight - topHeight

  love.graphics.rectangle(
    "fill",
    self.position.x,
    self.position.y + self.sprites.tabs.modules:getHeight() * 4,
    1024 - InventoryBag.Margin * 2,
    768
  )

  Color.Black:use()

  love.graphics.rectangle(
    "fill",
    self.position.x,
    self.position.y + self.sprites.tabs.modules:getHeight() * 4,
    leftWidth,
    768
  )

  love.graphics.rectangle(
    "fill",
    self.position.x + leftWidth,
    self.position.y + self.sprites.tabs.modules:getHeight() * 4,
    rightWidth,
    topHeight
  )

  love.graphics.rectangle(
    "fill",
    self.position.x + leftWidth,
    self.position.y + self.sprites.tabs.modules:getHeight() * 4 + topHeight,
    rightWidth,
    downHeight
  )
  Color.White:use()
end

function InventoryBag:draw()
  love.graphics.push()
  love.graphics.applyTransform(self.transform)

  for name, sprite in pairs(self.sprites.tabs) do
    if not (self.activeTab == name) then
      sprite:draw(
        self.position.x + (InventoryBag.TabsIndexes[name] - 1) * (sprite:getWidth() + 1) * 4,
        self.position.y,
        0,
        4,
        4
      )
    end
  end

  if InventoryBag.InventoryIndexes[self.activeTab] then
    self:drawInventoryPanel(self.slots[self.activeTab])
  elseif InventoryBag.CraftIndexes[self.activeTab] then
    self:drawCraftPanel(self.slots[self.activeTab])
  end

  Color.InventoryBorder:use()

  love.graphics.setLineWidth(InventoryBag.Border)
  love.graphics.rectangle(
    "line",
    self.position.x + InventoryBag.Border / 2,
    self.position.y + self.sprites.tabs.modules:getHeight() * 4 - InventoryBag.Border / 2,
    1024 - InventoryBag.Margin * 2 - InventoryBag.Border,
    768
  )
  love.graphics.setLineWidth(1)

  Color.White:use()

  self.sprites.tabs[self.activeTab]:draw(
    self.position.x + (InventoryBag.TabsIndexes[self.activeTab] - 1) * (self.sprites.tabs.modules:getWidth() + 1) * 4,
    self.position.y,
    0,
    4,
    4
  )
  love.graphics.pop()
end

return InventoryBag
