local wezterm = require 'wezterm'
local act = wezterm.action

local config = wezterm.config_builder()
config:set_strict_mode(true)

local is_windows = wezterm.target_triple:find('windows') ~= nil

config.font = wezterm.font 'JetBrains Mono'
-- Windows renders points larger than macOS, so 14 there looks huge
config.font_size = is_windows and 12 or 14
config.color_scheme = 'Catppuccin Mocha (Gogh)'

local TITLEBAR_COLOR = '#333333'
config.native_macos_fullscreen_mode = true
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.window_frame = {
  font = wezterm.font { family = 'JetBrains Mono', weight = 'Bold' },
  font_size = 13.0,
  active_titlebar_bg = TITLEBAR_COLOR,
  inactive_titlebar_bg = TITLEBAR_COLOR,
}

if is_windows then
  -- zsh from Git for Windows, as a login shell so /etc/profile sets up PATH
  local git_dir = 'C:/Program Files/Git'
  config.default_prog = { git_dir .. '/usr/bin/zsh.exe', '--login', '-i' }
  config.set_environment_variables = {
    MSYSTEM = 'MINGW64',
    CHERE_INVOKING = '1', -- start in the cwd rather than $HOME
  }
  config.launch_menu = {
    { label = 'zsh', args = { git_dir .. '/usr/bin/zsh.exe', '--login', '-i' } },
    { label = 'Git Bash', args = { git_dir .. '/bin/bash.exe', '--login', '-i' } },
    { label = 'PowerShell', args = { 'powershell.exe', '-NoLogo' } },
    { label = 'Command Prompt', args = { 'cmd.exe' } },
  }
end

local BACKGROUND_IMAGE = wezterm.home_dir .. '/.config/background.jpg'
local function file_exists(path)
  local f = io.open(path, 'r')
  if f then f:close() return true end
  return false
end

-- Switch between just an opacity and a background image based on whether we are fullscreen
local function set_background(config, is_fullscreen)
  if is_fullscreen and file_exists(BACKGROUND_IMAGE) then
    config.window_background_opacity = nil
    config.background = {
      {
        source = {
          File = BACKGROUND_IMAGE,
        },
        attachment = { Parallax = 0.1 },
        repeat_y = 'Mirror',
        horizontal_align = 'Center',
        opacity = 0.4,
        hsb = {
          hue = 1.0,
          saturation = 0.95,
          brightness = 0.5,
        },
      },
    }
  else
    config.window_background_opacity = 0.8
    config.macos_window_background_blur = 10
    config.win32_system_backdrop = 'Acrylic'
    config.background = nil
  end
end

-- Apply the windowed look at startup too (previously only on first resize)
set_background(config, false)

wezterm.on('window-resized', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  local is_fullscreen = window:get_dimensions().is_full_screen
  set_background(overrides, is_fullscreen)
  window:set_config_overrides(overrides)
end)

wezterm.on('update-status', function(window, pane)
  local cells = {}

  -- Figure out the hostname of the pane on a best-effort basis
  local hostname = wezterm.hostname()
  local cwd_uri = pane:get_current_working_dir()
  if cwd_uri and cwd_uri.host and cwd_uri.host ~= '' then
    hostname = cwd_uri.host
  end
  table.insert(cells, ' ' .. hostname)

  -- Format date/time in this style: "Wed Mar 3 08:14"
  local date = wezterm.strftime ' %a %b %-d %H:%M'
  table.insert(cells, date)

  -- Add an entry for each battery (typically 0 or 1)
  local batt_icons = {'', '', '', '', ''}
  for _, b in ipairs(wezterm.battery_info()) do
    local idx = math.max(1, math.min(#batt_icons, math.ceil(b.state_of_charge * #batt_icons)))
    local curr_batt_icon = batt_icons[idx]
    table.insert(cells, string.format('%s %.0f%%', curr_batt_icon, b.state_of_charge * 100))
  end

  -- Color palette for each cell
  local text_fg = '#c0c0c0'
  local colors = {
    TITLEBAR_COLOR,
    '#3c1361',
    '#52307c',
    '#663a82',
    '#7c5295',
    '#b491c8',
  }

  local elements = {}
  while #cells > 0 and #colors > 1 do
    local text = table.remove(cells, 1)
    local prev_color = table.remove(colors, 1)
    local curr_color = colors[1]

    table.insert(elements, { Background = { Color = prev_color } })
    table.insert(elements, { Foreground = { Color = curr_color } })
    table.insert(elements, { Text = '' })
    table.insert(elements, { Background = { Color = curr_color } })
    table.insert(elements, { Foreground = { Color = text_fg } })
    table.insert(elements, { Text = ' ' .. text .. ' ' })
  end
  window:set_right_status(wezterm.format(elements))
end)

-- ALT+o: open the pane's scrollback in an editor (helix if installed, else vim)
wezterm.on('open-hx-with-scrollback', function(window, pane)
  local text = pane:get_lines_as_text(pane:get_dimensions().scrollback_rows)
  local name = os.tmpname()
  local f = io.open(name, 'w+')
  f:write(text)
  f:flush()
  f:close()

  local editor = 'hx'
  local finder = is_windows and { 'where', 'hx' } or { 'which', 'hx' }
  local ok = pcall(function()
    local success = wezterm.run_child_process(finder)
    if not success then error('hx not found') end
  end)
  if not ok then
    editor = is_windows and 'C:/Program Files/Git/usr/bin/vim.exe' or 'vim'
  end

  window:perform_action(act.SpawnCommandInNewTab { args = { editor, name } }, pane)
  -- give the editor time to read the file before removing it
  wezterm.sleep_ms(1000)
  os.remove(name)
end)

config.keys = {
  { key = 'Enter', mods = 'ALT', action = act.ToggleFullScreen, },
  { key = 'q', mods = 'ALT', action = act.QuitApplication, },
  { key = 'o', mods = 'ALT', action = act.EmitEvent 'open-hx-with-scrollback', },

  { key = 'h', mods = 'ALT', action = act.ActivatePaneDirection 'Left', },
  { key = 'l', mods = 'ALT', action = act.ActivatePaneDirection 'Right', },
  { key = 'j', mods = 'ALT', action = act.ActivatePaneDirection 'Down', },
  { key = 'k', mods = 'ALT', action = act.ActivatePaneDirection 'Up', },

  { key = 'h', mods = 'SHIFT|ALT', action = act.AdjustPaneSize {'Left', 4}, },
  { key = 'l', mods = 'SHIFT|ALT', action = act.AdjustPaneSize {'Right', 4}, },
  { key = 'j', mods = 'SHIFT|ALT', action = act.AdjustPaneSize {'Down', 4}, },
  { key = 'k', mods = 'SHIFT|ALT', action = act.AdjustPaneSize {'Up', 4}, },

  { key = 'd', mods = 'ALT', action = act.SplitVertical, },
  { key = 'r', mods = 'ALT', action = act.SplitHorizontal, },

  { key = '[', mods = 'ALT', action = act.ActivateTabRelative(-1), },
  { key = ']', mods = 'ALT', action = act.ActivateTabRelative(1), },
  { key = 'e', mods = 'ALT', action = act.CloseCurrentPane {confirm = true} },
  { key = 't', mods = 'ALT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'l', mods = 'CTRL|SHIFT|ALT', action = act.ShowLauncher },

  -- Floating panes (not implemented yet)
    -- bind "Alt w" { ToggleFloatingPanes; }
    -- bind "Alt e" { TogglePaneEmbedOrFloating; }
    -- bind "Alt b" { MovePaneBackwards; }

  -- Using defaults for tabs (CMD t, CMD 1-9)
  -- Using defaults for find (CMD f, CTRL-r to toggle case sensitivity & regex modes) 
}

config.audible_bell = "Disabled"

config.initial_rows = 42
config.initial_cols = 160

return config
