local bank = require("aliensignal.bank")
local peachy = require("peachy")
local Button = require("aliensignal.button")
local Color = require("aliensignal.color")
local Event = require("event")
local Object = require("classic")
local Junk = require("aliensignal.junk")
local Module = require("aliensignal.module")
local SignalScreen = require("aliensignal.signalscreen")
local Animation = require("animation")

local AndGate = require("aliensignal.module.andgate")
local OrGate = require("aliensignal.module.orgate")
local Booster = require("aliensignal.module.booster")
local Decreaser = require("aliensignal.module.decreaser")
local Coupler = require("aliensignal.module.coupler")
local NotGate = require("aliensignal.module.notgate")
local Phaser = require("aliensignal.module.phaser")
local Wire = require("aliensignal.module.wire")
local DownLeftShoulder = require("aliensignal.module.downleftshoulder")
local DownRightShoulder = require("aliensignal.module.downrightshoulder")
local UpLeftShoulder = require("aliensignal.module.upleftshoulder")
local UpRightShoulder = require("aliensignal.module.uprightshoulder")

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
  build = 648,
  signal = 648
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

InventoryBag.SignalScreen = SignalScreen:extend()

function InventoryBag.SignalScreen:new(inventoryBag, ...)
  SignalScreen.new(self, ...)

  self.inventoryBag = inventoryBag
  self.show = {
    guides = false,
    mainSignal = false
  }
end

function InventoryBag.SignalScreen:computeSignalAtTime(time, name)
  local junkItem = self.inventoryBag.craftables.signal[self.inventoryBag.craftableSelected.signal]

  return junkItem.signal[math.floor(time * self.exportTimeCoef)]
end

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

function InventoryBag.Slot:pop()
  return table.remove(self.items, #self.items)
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
  InventoryBag.x2Font = love.graphics.newFont("assets/fonts/emulogic.ttf", 24)
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

  self.showSignal = true
  self.activeTab = "modules"
  self.navigator = navigator
  self.transform = love.math.newTransform()
  self.opened = false
  self.onDrop = Event()
  self.onSetSignal = Event()
  self.slots = {
    modules = {},
    junk = {}
  }

  self.craftableSelected = {
    build = 1,
    signal = 1
  }

  self.craftables = {
    build = {
      AndGate(),
      OrGate(),
      Booster(),
      Decreaser(),
      Coupler(),
      NotGate(),
      Phaser(),
      Wire(),
      DownLeftShoulder(),
      DownRightShoulder(),
      UpLeftShoulder(),
      UpRightShoulder()
    },
    signal = {
      Junk.Fork(),
      Junk.Coin(),
      Junk.Battery(),
      Junk.LightBulb(),
      Junk.Trophy(),
      Junk.Boombox(),
      Junk.Microphone(),
      Junk.GameBoy(),
      Junk.FloppyDisk(),
      Junk.MapleSyrupCan(),
      Junk.Shield(),
      Junk.SonicScrewdriver()
    }
  }

  self.inventory = {
    modules = {},
    junk = {}
  }

  self.position = {
    x = InventoryBag.Margin,
    y = 768 - self.sprites.tabs.modules:getHeight() * 4 + InventoryBag.Border
  }

  self.buttons = {
    build = Button("BUILD", InventoryBag.x2Font, {x = 782, y = 1248}, {width = 160, height = 66}, self.transform),
    signal = Button("SET", InventoryBag.x2Font, {x = 782, y = 1120}, {width = 160, height = 66}, self.transform)
  }

  self.signalScreen = InventoryBag.SignalScreen(self, {x = 400, y = 928}, 544)

  self.builtText = love.graphics.newText(InventoryBag.Font, "BUILT!")
  self.builtTextProperties = {
    x = self.buttons.build.position.x + 50,
    y = self.buttons.build.position.y - 20,
    alpha = 0
  }

  self.signalText =
    "This is the signal you must use to attract this item from the pile of junk.\nClick the 'SET' button to add it as a target on your signal screen."
  self.signalTextPosition = {
    x = self.position.x + 370,
    y = self.position.y + 120,
    limit = 500
  }
end

function InventoryBag:fill(inventory)
  self.inventory = inventory
end

function InventoryBag:prepareSlots()
  self:prepareStorageSlots("modules")
  self:prepareStorageSlots("junk")
  self:prepareCraftables("build")
  self:prepareCraftables("signal")
end

function InventoryBag:countItems(storage, name)
  local count = 0

  for index, item in ipairs(self.inventory[storage]) do
    count = item.name == name and count + 1 or count
  end

  return count
end

function InventoryBag:prepareCraftables(tab)
  local fullWidth = 1024 - InventoryBag.Margin * 2
  local fullHeight = InventoryBag.Heights[tab]
  local leftWidth = math.floor(fullWidth / 3)
  local rightWidth = fullWidth - leftWidth
  local topHeight = math.floor(fullHeight / 3)
  local downHeight = fullHeight - topHeight

  local verticalMargin = math.ceil(((InventoryBag.Heights[tab] / 12) - InventoryBag.ItemSize / 4) / 2)
  local horizontalMargin = 16

  for index, craftable in ipairs(self.craftables[tab]) do
    local y = 768 + verticalMargin + (index - 1) * (verticalMargin * 2 + InventoryBag.ItemSize / 4)

    craftable.position = {
      x = self.position.x + horizontalMargin,
      y = y
    }
    craftable.scale = 1

    craftable.hitslop = {
      x = craftable.position.x - 16,
      y = craftable.position.y - verticalMargin,
      width = leftWidth,
      height = 2 * verticalMargin + InventoryBag.ItemSize / 4
    }

    craftable:renderDisplayableName(
      InventoryBag.Font,
      Color.White,
      {
        x = math.floor(craftable.position.x + InventoryBag.ItemSize / 4 + horizontalMargin),
        y = math.floor(y + InventoryBag.ItemSize / 2) - 55
      }
    )

    if craftable.description then
      craftable:renderDescription(
        InventoryBag.Font,
        Color.Description,
        {
          x = math.floor(self.position.x + leftWidth + 64),
          y = math.floor(self.craftables[tab][1].position.y + InventoryBag.ItemSize * 2 / 3)
        }
      )
    end

    if craftable.requirements then
      self.buttons.build.enabled = true
      for index, requirement in ipairs(craftable.requirements) do
        local count = self:countItems("junk", requirement[2].name)
        local required = requirement[1]

        -- if count + 1 < required then -- WEIRD
        --   self.buttons.build.enabled = false
        -- end

        if not requirement[2].initialDisplayableName then
          requirement[2].initialDisplayableName = requirement[2].displayableName
        else
          requirement[2].displayableName = requirement[2].initialDisplayableName
        end

        requirement[2].visible = false

        requirement[2].displayableName =
          Color.Text():concat(Color.Signal or Color.TargetSignal, count .. "/" .. tostring(requirement[1])):concat(
          Color.White,
          " " .. requirement[2].displayableName
        ):dump()

        requirement[2]:renderDisplayableName(
          InventoryBag.Font,
          count >= required and Color.Signal or Color.TargetSignal,
          {
            x = math.floor(self.position.x + leftWidth + 64),
            y = math.floor(self.craftables[tab][1].position.y + InventoryBag.ItemSize * 2 / 3) + 128 + (index + 1) * 32
          }
        )
      end
    end
  end
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

function InventoryBag:popByName(storage, name)
  local pickedSlot = nil

  for index, slot in pairs(self.slots[storage]) do
    if slot.name == name then
      pickedSlot = slot
      break
    end
  end

  return self:pop(pickedSlot:pop())
end

function InventoryBag:store(storage, item)
  local existInInventory = false

  for index, other in pairs(self.inventory[storage]) do
    if other == item then
      existInInventory = true
      break
    end
  end

  if not existInInventory then
    table.insert(self.inventory[storage], item)
  end

  for index, slot in pairs(self.slots[storage]) do
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

function InventoryBag:checkCraftMousePressed(x, y)
  for index, craftable in ipairs(self.craftables[self.activeTab]) do
    if
      x >= craftable.hitslop.x and x <= craftable.hitslop.x + craftable.hitslop.width and
        y >= craftable.hitslop.y - InventoryBag.Heights[self.activeTab] and
        y <= craftable.hitslop.y - InventoryBag.Heights[self.activeTab] + craftable.hitslop.height
     then
      self.craftableSelected[self.activeTab] = index
      break
    end
  end
end

function InventoryBag:build()
  local mod = self.craftables.build[self.craftableSelected.build]
  local hasRequirements = true

  for index, requirement in ipairs(mod.requirements) do
    local count = self:countItems("junk", requirement[2].name)
    local required = requirement[1]

    if count < required then
      hasRequirements = false
      break
    end
  end

  if hasRequirements then
    for index, requirement in ipairs(mod.requirements) do
      for n = 1, requirement[1], 1 do
        self:popByName("junk", requirement[2].name)
      end
    end

    self:store("modules", mod:clone())
    self:prepareSlots()

    -- play built animation
    self.builtTextProperties = {
      x = self.buttons.build.position.x + 50,
      y = self.buttons.build.position.y - 20,
      alpha = 1
    }
    self.builtTextAnimation =
      Animation.Series(
      {
        Animation.Tween(0.3, self.builtTextProperties, {y = self.buttons.build.position.y - 50}),
        Animation.Tween(0.3, self.builtTextProperties, {alpha = 0})
      }
    )
    self.builtTextAnimation.onComplete:listenOnce(
      function()
        self.builtTextProperties.alpha = 0
      end
    )
    self.builtTextAnimation:start()
  end
end

function InventoryBag:setSignal()
  local junkItem = self.craftables.signal[self.craftableSelected.signal]

  self.onSetSignal:trigger(junkItem.signal)
end

function InventoryBag:mousepressed(x, y, button)
  if
    self.opened and InventoryBag.CraftIndexes[self.activeTab] and
      self.buttons[self.activeTab]:mousepressed(x, y, button)
   then
    if self.activeTab == "build" then
      self:build()
    else
      self:setSignal()
    end
    return true
  elseif self:tabPressed(x, y, button, "modules") then
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
  elseif self:tabPressed(x, y, button, "signal") and self.showSignal then
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
  elseif self.opened and button == 1 and InventoryBag.CraftIndexes[self.activeTab] then
    self:checkCraftMousePressed(x, y)
  end
end

function InventoryBag:mousereleased(x, y, button, istouch)
  if self.opened and InventoryBag.CraftIndexes[self.activeTab] then
    self.buttons[self.activeTab]:mousereleased(x, y, button)
  elseif self.opened and self.activeTab == "modules" then
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

  if InventoryBag.CraftIndexes[self.activeTab] then
    for index, craftable in ipairs(self.craftables[self.activeTab]) do
      craftable:update(dt)
    end
  end

  if self.activeTab == "signal" then
    self.signalScreen:update(dt)
  end

  if self.builtTextAnimation then
    self.builtTextAnimation:update(dt)
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
  local verticalMargin = math.ceil(((InventoryBag.Heights.build / 12) - InventoryBag.ItemSize / 4) / 2)

  Color.InventoryBorder:use()

  love.graphics.rectangle(
    "fill",
    self.position.x,
    self.position.y + self.sprites.tabs.modules:getHeight() * 4,
    1024 - InventoryBag.Margin * 2,
    768
  )

  Color.White:use()

  for index, craftable in ipairs(self.craftables[self.activeTab]) do
    local selected = self.craftableSelected[self.activeTab] == index
    local color =
      selected and Color.CraftListItemSelected or
      ((index - 1) % 2 == 0 and Color.CraftListItemEven or Color.CraftListItemOdd)

    color:use()

    love.graphics.rectangle(
      "fill",
      craftable.hitslop.x,
      craftable.hitslop.y,
      craftable.hitslop.width,
      craftable.hitslop.height
    )

    Color.White:use()
    craftable:draw()

    if selected and craftable.requirements and craftable.description then
      love.graphics.rectangle(
        "fill",
        self.position.x + leftWidth + 32,
        self.craftables[self.activeTab][1].position.y + InventoryBag.ItemSize * 2 / 3 - 32,
        565,
        128
      )

      craftable:drawDescription()

      if craftable.requirements then
        for index, requirement in ipairs(craftable.requirements) do
          requirement[2]:draw()
        end
      end
    end
  end

  self.buttons[self.activeTab]:draw()

  Color.White:use(self.builtTextProperties.alpha)
  love.graphics.draw(self.builtText, self.builtTextProperties.x, self.builtTextProperties.y)
  Color.White:use()

  if self.activeTab == "signal" then
    self.signalScreen:draw()
    love.graphics.printf(
      self.signalText,
      InventoryBag.Font,
      self.signalTextPosition.x,
      self.signalTextPosition.y,
      self.signalTextPosition.limit
    )
  end
end

function InventoryBag:draw()
  love.graphics.push()
  love.graphics.applyTransform(self.transform)

  for name, sprite in pairs(self.sprites.tabs) do
    if not (self.activeTab == name) and (self.showSignal or not (name == "signal")) then
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
    self:drawCraftPanel(self.craftables[self.activeTab])
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
