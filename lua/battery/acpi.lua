-- Support for linux via acpi
-- Note that this only works if you install acpi 
--   apt install acpi

local J = require("plenary.job")
local L = require("plenary.log")

local log = L.new({ plugin = "battery" })

-- TODO would be nice to unit test the parser
--[[ Sample output:

Without ac power connected you see...

Battery 0: Discharging, 48%, 02:21:28 remaining

When ac power is connected you see...

Battery 0: Charging, 47%, 01:09:53 until charged

]]
--

-- Parse the response from the battery info job and update
-- the battery status
local function parse_acpi_battery_info(result, battery_status)
  local count = 0
  local charge_total = 0
  local ac_power = nil

  for _, line in ipairs(result) do
    local found, _, charge = line:find("(%d+)%%")
    local discharge = line:find("Discharging")
    if found then
      count = count + 1
      charge_total = charge_total + tonumber(charge)
      -- only the first battery is used to determine charging or not
      -- since they should all be the same
      if not ac_power then
        if discharge == nil then
          ac_power = true
        else
          ac_power = false
        end
      end
    end
  end
  if count > 0 then
    battery_status.percent_charge_remaining = math.floor(charge_total / count)
    battery_status.battery_count = count
    battery_status.ac_power = ac_power
  else
    battery_status.percent_charge_remaining = 100
    battery_status.battery_count = count
    battery_status.ac_power = false
  end
end

-- Create a plenary job to get the battery info
-- battery_status is a table to store the results in
local function get_battery_info_job(battery_status)
  return J:new({
    command = "acpi",
    on_exit = function(r, return_value)
      if return_value == 0 then
        parse_acpi_battery_info(r:result(), battery_status)
        log.debug(vim.inspect(battery_status))
      else
        log.error(vim.inspect(r:result()))
        vim.schedule(function()
          vim.notify("battery.nvim: Error getting battery info with acpi", vim.log.levels.ERROR)
        end)
      end
    end,
  })
end

return {
  get_battery_info_job = get_battery_info_job,
}
