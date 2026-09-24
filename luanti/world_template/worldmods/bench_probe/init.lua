-- bend-voxel-bench probe. Area: mapchunks with node origins x, z = -32 + 80k
-- (k = 0..4) and y = -112 + 80k (k = 0..3), the same 100 as the Bend bench.
local P1 = {x = -32, y = -112, z = -32}
local P2 = {x = 367, y = 207, z = 367}
local OUT = core.get_worldpath() .. "/bench_probe.txt"

local function cid(name)
  return core.get_content_id(core.registered_aliases[name] or name)
end

-- one line per mapchunk, same format as the Bend dump
local function export(f)
  local c_stone = cid("mapgen_stone")
  local c_water = cid("mapgen_water_source")
  for cy = 0, 3 do for cz = 0, 4 do for cx = 0, 4 do
    local x0, y0, z0 = -32 + 80 * cx, -112 + 80 * cy, -32 + 80 * cz
    local vm = core.get_voxel_manip()
    local emin, emax = vm:read_from_map({x = x0, y = y0, z = z0}, {x = x0 + 79, y = y0 + 79, z = z0 + 79})
    local area = VoxelArea:new({MinEdge = emin, MaxEdge = emax})
    local data = vm:get_data()
    local parts = {string.format("%d %d %d", x0, y0, z0)}
    for z = z0, z0 + 79 do
      for x = x0, x0 + 79 do
        local stone, water = 0, 0
        for y = y0, y0 + 79 do
          local c = data[area:index(x, y, z)]
          if c == c_stone then stone = stone + 1 elseif c == c_water then water = water + 1 end
        end
        parts[#parts + 1] = stone .. " " .. water
      end
    end
    f:write(table.concat(parts, " "), "\n")
  end end end
end

core.after(0, function()
  local errors = 0
  local t0 = core.get_us_time()
  core.emerge_area(P1, P2, function(_, action, remaining)
    if action == core.EMERGE_ERRORED or action == core.EMERGE_CANCELLED then
      errors = errors + 1
    end
    if remaining > 0 then return end
    local t1 = core.get_us_time()
    local f = assert(io.open(OUT, "w"))
    f:write(string.format("emerge_us %d errors %d\n", t1 - t0, errors))
    export(f)
    f:close()
    core.request_shutdown("bench_probe done", false, 0)
  end)
end)
