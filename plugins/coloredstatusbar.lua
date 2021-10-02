-- mod-version:2 -- lite-xl 2.00
local core = require "core"
local style = require "core.style"
local common = require "core.common"
local StatusView = require "core.statusview"
local ToolbarView = require "plugins.toolbarview"

local white = { common.color "#ffffff" }
local color = { common.color "#24292f" }

function StatusView:draw_background()
  local x, y = self.position.x, self.position.y
  local w, h = self.size.x, self.size.y
  renderer.draw_rect(x, y, w + x % 1, h + y % 1, color)
end

local draw = StatusView.draw
function StatusView:draw(...)
  local old = style.text
  style.text = white
  draw(self, ...)
  style.text = old
end

