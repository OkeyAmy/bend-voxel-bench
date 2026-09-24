-- bend-voxel-bench probe. Area: 5 x 4 x 5 mapchunks with node origins
-- x = X0 + 80k, z = Z0 + 80k (k = 0..4) and y = -112 + 80k (k = 0..3): the same
-- 100 as the Bend bench. X0, Z0 come from the settings bench_x0, bench_z0
-- (mapchunk-aligned, default -32).
local X0 = tonumber(core.settings:get("bench_x0") or "-32")
local Z0 = tonumber(core.settings:get("bench_z0") or "-32")
local P1 = {x = X0, y = -112, z = Z0}
local P2 = {x = X0 + 399, y = 207, z = Z0 + 399}
local OUT = core.get_worldpath() .. "/bench_probe.txt"

local function cid(name)
  return core.get_content_id(core.registered_aliases[name] or name)
end

-- one line per mapchunk, same format as the Bend dump
local function export(f)
  local c_stone = cid("mapgen_stone")
  local c_water = cid("mapgen_water_source")
  for cy = 0, 3 do for cz = 0, 4 do for cx = 0, 4 do
    local x0, y0, z0 = X0 + 80 * cx, -112 + 80 * cy, Z0 + 80 * cz
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

-- With several emerge threads, a block whose mapchunk another thread is already
-- generating comes back EMERGE_CANCELLED. Re-emerge the area until a pass has no
-- cancelled block (generated blocks return from memory), then stop the clock.
local MAX_PASSES = 20

core.after(0, function()
  local errors, cancelled, passes = 0, 0, 0
  local t0 = core.get_us_time()
  local function pass()
    passes = passes + 1
    local cancelled_now = 0
    core.emerge_area(P1, P2, function(_, action, remaining)
      if action == core.EMERGE_ERRORED then
        errors = errors + 1
      elseif action == core.EMERGE_CANCELLED then
        cancelled_now = cancelled_now + 1
      end
      if remaining > 0 then return end
      cancelled = cancelled + cancelled_now
      if cancelled_now > 0 and errors == 0 and passes < MAX_PASSES then
        pass()
        return
      end
      if cancelled_now > 0 then errors = errors + cancelled_now end
      local t1 = core.get_us_time()
      local f = assert(io.open(OUT, "w"))
      f:write(string.format("emerge_us %d errors %d cancelled %d passes %d\n", t1 - t0, errors, cancelled, passes))
      export(f)
      f:close()
      core.request_shutdown("bench_probe done", false, 0)
    end)
  end
  pass()
end)
