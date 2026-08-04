-- Vertical app stack on one portrait display + Ghostty fullscreen on the other, on one hotkey.

local HOTKEY = { { "ctrl", "option", "cmd" }, "l" } -- option is the same modifier Hammerspoon calls "alt"
local STACK = { "Google Chrome", "Spotify", "Slack" } -- top to bottom
local FULLSCREEN_APP = "Ghostty"
local STACK_ON = "secondary" -- "primary" is the menu-bar display, which here is Ghostty's

hs.window.animationDuration = 0
require("hs.ipc") -- lets `hs -c "..."` drive this config from a terminal

-- Resolved per keypress, never cached, so rotation/resolution/disconnect changes take effect at once.
local function targetScreens()
  local primary = hs.screen.primaryScreen()
  local other
  for _, s in ipairs(hs.screen.allScreens()) do
    if s:getUUID() ~= primary:getUUID() then
      other = other or s
    end
  end
  if STACK_ON == "secondary" and other then
    return other, primary
  end
  return primary, other
end

-- Integer boundaries shared between adjacent slots: exact coverage, no 1px gap or overlap.
local function slice(f, n)
  local rects = {}
  for i = 0, n - 1 do
    local top = math.floor(f.y + f.h * i / n + 0.5)
    local bottom = math.floor(f.y + f.h * (i + 1) / n + 0.5)
    rects[i + 1] = hs.geometry.rect(f.x, top, f.w, bottom - top)
  end
  return rects
end

local function windowFor(appName)
  local app = hs.application.get(appName)
  if not app then
    return nil
  end
  local win = app:mainWindow()
  if not win then
    for _, w in ipairs(app:allWindows()) do
      if w:isStandard() then
        win = w
        break
      end
    end
  end
  if win and win:isMinimized() then
    win:unminimize()
  end
  return win
end

-- A setFrame lands late or not at all mid-animation or right after unminimize, so verify and retry.
local function place(win, rect)
  for _ = 1, 3 do
    win:setFrame(rect)
    local got = win:frame()
    if math.max(math.abs(got.x - rect.x), math.abs(got.y - rect.y),
      math.abs(got.w - rect.w), math.abs(got.h - rect.h)) <= 2 then
      return true
    end
  end
  return false
end

-- Native fullscreen gets its own Space and vanishes whenever that Space is not showing, and no
-- hotkey can pull a Space forward, so fill the screen in the normal Space instead.
local function fillScreen(win, screen, tries)
  if win:isFullScreen() then
    if (tries or 0) >= 3 then
      hs.alert.show(FULLSCREEN_APP .. ": stuck in fullscreen, exit it manually")
      return
    end
    win:setFullScreen(false)
    hs.timer.doAfter(1, function()
      fillScreen(win, screen, (tries or 0) + 1)
    end)
    return
  end
  place(win, screen:frame())
  win:raise()
end

local function isLayoutApp(name)
  if name == FULLSCREEN_APP then
    return true
  end
  for _, n in ipairs(STACK) do
    if n == name then
      return true
    end
  end
  return false
end

local function applyLayout()
  if not hs.accessibilityState() then
    hs.alert.show("Grant Hammerspoon Accessibility access, then press the hotkey again")
    return
  end

  local stackScreen, otherScreen = targetScreens()
  local slots = slice(stackScreen:frame(), #STACK)
  local skipped = {}

  local firstPlaced
  for i, name in ipairs(STACK) do
    local win = windowFor(name)
    if win and place(win, slots[i]) then
      win:raise()
      firstPlaced = firstPlaced or win
    else
      table.insert(skipped, name)
    end
  end

  local fs = windowFor(FULLSCREEN_APP)
  if not otherScreen then
    table.insert(skipped, FULLSCREEN_APP .. " (needs a 2nd display)")
  elseif fs then
    fillScreen(fs, otherScreen)
  else
    table.insert(skipped, FULLSCREEN_APP)
  end

  -- macOS keeps the focused app's windows above raised ones, so an unlisted app would stay on top.
  local front = hs.application.frontmostApplication()
  if firstPlaced and not (front and isLayoutApp(front:name())) then
    firstPlaced:focus()
  end

  if #skipped > 0 then
    hs.alert.show("Skipped: " .. table.concat(skipped, ", "))
  else
    hs.alert.show("Layout set")
  end
end

hs.hotkey.bind(HOTKEY[1], HOTKEY[2], applyLayout)

-- Global on purpose: an unretained pathwatcher is garbage collected and silently stops watching.
configWatcher = hs.pathwatcher.new(hs.configdir, function(files)
  for _, f in ipairs(files) do
    if f:sub(-4) == ".lua" then
      hs.reload()
      return
    end
  end
end):start()

hs.alert.show("Layout config loaded")
