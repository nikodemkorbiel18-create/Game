--!nocheck
-- Prints time-to-reach each zone for a non-paying player using the current configs.
-- Usage: lune run tools/simulate [runs] [verbose]
local process = require("@lune/process")
local rbx = require("./lib/rbx")
local env = rbx.load()
local Simulator = env.require("ReplicatedStorage/Shared/Balancing/Simulator")
local runs = tonumber(process.args[1]) or 5
Simulator.Run(runs, process.args[2] == "verbose")
