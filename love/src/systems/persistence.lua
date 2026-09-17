local P = {}
local SAVE = "tilemama.sav"

local function serialize(v, depth)
  depth = depth or 0
  local t = type(v)
  if t=="number" then
    if v~=v then return "0/0" end
    if v==math.huge then return "math.huge" end
    if v==-math.huge then return "-math.huge" end
    return tostring(v)
  elseif t=="boolean" then return v and "true" or "false"
  elseif t=="string" then return string.format("%q", v)
  elseif t=="table" then
    -- check array vs dict
    local isArray=true
    local n=#v
    local count=0
    for k,_ in pairs(v) do count=count+1; if type(k)~="number" or k<1 or k>n or math.floor(k)~=k then isArray=false; break end end
    if isArray and count==n then
      local parts={}
      for i=1,n do table.insert(parts, serialize(v[i], depth+1)) end
      return "{"..table.concat(parts,",").."}"
    else
      local parts={}
      for k,val in pairs(v) do
        local key
        if type(k)=="string" and k:match("^[A-Za-z_][A-Za-z0-9_]*$") then key=k
        else key="["..serialize(k,depth+1).."]" end
        table.insert(parts, key.."="..serialize(val,depth+1))
      end
      return "{"..table.concat(parts,",").."}"
    end
  elseif t=="nil" then return "nil"
  else return "nil" end
end

function P.save(state)
  local content = "return "..serialize(state)
  love.filesystem.write(SAVE, content)
end

function P.load()
  if not love.filesystem.getInfo(SAVE) then return nil end
  local content = love.filesystem.read(SAVE)
  if not content or content=="" then return nil end
  local loader = loadstring or load
  local chunk, err = loader(content)
  if not chunk then return nil end
  local ok, res = pcall(chunk)
  if not ok then return nil end
  if type(res)~="table" then return nil end
  return res
end

function P.clear()
  if love.filesystem.getInfo(SAVE) then love.filesystem.remove(SAVE) end
end

return P
