-- Vertical app stack on one portrait display + Ghostty filling the other, on one hotkey.

local HOTKEY = { { "ctrl", "option", "cmd" }, "l" } -- option is the same modifier Hammerspoon calls "alt"
local STACK = { "Google Chrome", "Spotify", "Slack" } -- top to bottom
local FULLSCREEN_APP = "Ghostty"
local STACK_ON = "secondary" -- "primary" is the menu-bar display, which here is Ghostty's

local LAUNCH_TIMEOUT = 20 -- a cold start can be slow, and waiting costs nothing when it is not
local UNFULLSCREEN_TIMEOUT = 5
local POLL = 0.2

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

-- Hammerspoon runs on one thread, so the layout pass runs inside a coroutine and yields to a timer
-- whenever it has to wait. Blocking instead would freeze the very animations it is waiting on.
local function sleep(seconds)
  local co = coroutine.running()
  hs.timer.doAfter(seconds, function()
    local ok, err = coroutine.resume(co)
    if not ok then
      hs.showError(err)
    end
  end)
  coroutine.yield()
end

-- Returns the first truthy value predicate produces, or nil once timeout has elapsed.
local function waitFor(predicate, timeout)
  local waited = 0
  while true do
    local value = predicate()
    if value then
      return value
    end
    if waited >= timeout then
      return nil
    end
    sleep(POLL)
    waited = waited + POLL
  end
end

-- Only standard windows: a launching app can briefly expose a splash or panel as its main window.
local function windowFor(appName)
  local app = hs.application.get(appName)
  if not app then
    return nil
  end
  if app:isHidden() then
    app:unhide() -- a hidden app's windows still resize, but invisibly
  end
  local win = app:mainWindow()
  if not (win and win:isStandard()) then
    win = nil
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

-- Launches the app when it is closed, and waits for a real window either way.
local function acquireWindow(appName)
  local win = windowFor(appName)
  if win then
    return win
  end
  if not hs.application.launchOrFocus(appName) then
    return nil, appName .. " (not found)"
  end
  win = waitFor(function()
    return windowFor(appName)
  end, LAUNCH_TIMEOUT)
  if not win then
    return nil, appName .. " (no window after launch)"
  end
  return win
end

-- A native-fullscreen window lives on its own Space and refuses to be resized, so it has to be
-- taken out of fullscreen first, and the exit animation has to finish before setFrame will stick.
local function leaveFullScreen(win, appName)
  if not win:isFullScreen() then
    return true
  end
  win:setFullScreen(false)
  local left = waitFor(function()
    return not win:isFullScreen()
  end, UNFULLSCREEN_TIMEOUT)
  if not left then
    return false, appName .. " (stuck in fullscreen, exit it manually)"
  end
  sleep(0.3) -- the Space teardown lands a beat after the flag flips
  return true
end

local function fits(got, want)
  return math.max(math.abs(got.x - want.x), math.abs(got.y - want.y),
    math.abs(got.w - want.w), math.abs(got.h - want.h)) <= 2
end

-- A setFrame lands late or not at all mid-animation, right after unminimize, or while an app is
-- still finishing its launch, so verify and retry with a pause between attempts.
local function place(win, rect)
  for attempt = 1, 5 do
    win:setFrame(rect)
    if fits(win:frame(), rect) then
      return true
    end
    if attempt < 5 then
      sleep(POLL)
    end
  end
  return false
end

-- Places the app in rect, taking it out of fullscreen and launching it first if needed.
-- Returns the window, or nil plus a reason for the "Skipped" alert.
local function placeApp(appName, rect)
  local win, err = acquireWindow(appName)
  if not win then
    return nil, err
  end
  local ok
  ok, err = leaveFullScreen(win, appName)
  if not ok then
    return nil, err
  end
  if not place(win, rect) then
    return nil, appName .. " (window would not resize)"
  end
  win:raise()
  return win
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

local function layoutPass()
  local stackScreen, otherScreen = targetScreens()
  local slots = slice(stackScreen:frame(), #STACK)
  local skipped = {}

  local firstPlaced
  for i, name in ipairs(STACK) do
    local win, err = placeApp(name, slots[i])
    if win then
      firstPlaced = firstPlaced or win
    else
      table.insert(skipped, err)
    end
  end

  -- Native fullscreen gets its own Space and vanishes whenever that Space is not showing, and no
  -- hotkey can pull a Space forward, so fill the screen in the normal Space instead.
  if not otherScreen then
    table.insert(skipped, FULLSCREEN_APP .. " (needs a 2nd display)")
  else
    local _, err = placeApp(FULLSCREEN_APP, otherScreen:frame())
    if err then
      table.insert(skipped, err)
    end
  end

  -- macOS keeps the focused app's windows above raised ones, so an unlisted app would stay on top.
  -- Launching an app also steals focus, so re-check here rather than before the placements.
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

-- One pass at a time: a pass can now stay alive for seconds waiting on a launch, and two of them
-- interleaving would fight over the same slots.
local inProgress = false

local function applyLayout()
  if not hs.accessibilityState() then
    hs.alert.show("Grant Hammerspoon Accessibility access, then press the hotkey again")
    return
  end
  if inProgress then
    return
  end
  inProgress = true

  local co = coroutine.create(function()
    -- xpcall so the guard is released even when a pass throws; it is yieldable, so the sleeps
    -- inside layoutPass still work through it.
    local ok, err = xpcall(layoutPass, debug.traceback)
    inProgress = false
    if not ok then
      hs.showError(err)
    end
  end)
  local ok, err = coroutine.resume(co)
  if not ok then
    inProgress = false
    hs.showError(err)
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
