function love.conf(t)
  t.identity = "tilemama"
  t.version = "11.5"
  t.window.title = "TileMama - LÖVE"
  t.window.width = 720
  t.window.height = 1280
  t.window.minwidth = 360
  t.window.minheight = 640
  t.window.resizable = true
  t.window.highdpi = true
  t.window.vsync = 1
  t.modules.joystick = false
  t.modules.physics = false
end
