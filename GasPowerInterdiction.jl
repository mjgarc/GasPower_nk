import PowerModels
import GasModels
import GasPowerModels
import Infiltrator
import JSON
import Ipopt
include("nk_interdiction.jl")

pfile = joinpath("stochastic_nk", "data", "matpower", "EP36.m")
gfile = joinpath("stochastic_nk", "data", "matgas", "NG146.m")
lfile = joinpath("stochastic_nk", "data", "link", "NG146-EP36.json")
pdata = PowerModels.parse_file(pfile; validate = false)
ptempdata = PowerModels.parse_file(pfile; validate = false)
gdata = GasModels.parse_file(gfile)
ldata = JSON.parsefile(lfile)
PowerModels.make_per_unit!(pdata)
resultdcopf = PowerModels.solve_dc_opf(pdata, Ipopt.Optimizer)

GasModels.make_si_units!(gdata)
for (d, d_dict) in ldata["it"]["dep"]["delivery_gen"]
    gdata["delivery"][d_dict["delivery"]["id"]]["withdrawal_max"] = (pdata["baseMVA"] * gdata["standard_density"] * gdata["energy_factor"] * d_dict["heat_rate_curve_coefficients"][2])* resultdcopf["solution"]["gen"][d_dict["gen"]["id"]]["pg"]
end


deliverygens=[dg_dict["delivery"]["id"] for (dg,dg_dict) in ldata["it"]["dep"]["delivery_gen"]]

for (r,r_dict) in gdata["receipt"]
    if "injection_min" in keys(r_dict)
        r_dict["injection_min"] = 0.0
        r_dict["is_dispatchable"] = 1
    end
end

max_load=0
for (d,d_dict) in gdata["delivery"]
    d_dict["withdrawal_min"] = 0.0
    d_dict["is_dispatchable"] = 1
    global max_load = max_load + d_dict["withdrawal_max"]
end
# Infiltrator.@infiltrate
# TODO: Is this the right interface, or should I really be passing filenames around?
# We are modifying data in-place here (e.g. add_total_load_info). Will that
# become a problem?
# GasModels.make_per_unit!(gdata)
# Making this data per-unit is required for Kaarthik's n-k interdiction.

# Will this cause problems elsewhere?
results = run_gas_interdiction(gdata; budget = 10)
display(results)

maxload = sum(g_dict["withdrawal_max"] for (g,g_dict) in gdata["delivery"])
maxgen = sum(r_dict["injection_max"] for (r,r_dict) in gdata["receipt"])
display(results.solution.load_shed / maxload)


data = GasPowerModels.parse_files(gfile, pfile, lfile)
GasPowerModels.correct_network_data!(data)
for i in results.solution.receipt
    data["it"]["gm"]["receipt"][string(i)]["status"] = 0
end


for (r,r_dict) in data["it"]["gm"]["receipt"]
    if "injection_min" in keys(r_dict)
        r_dict["injection_min"] = 0.0
        r_dict["is_dispatchable"] = 1
    end
end
max_load=0
for (d,d_dict) in data["it"]["gm"]["delivery"]
    d_dict["withdrawal_min"] = 0.0
    d_dict["is_dispatchable"] = 1
    global max_load = max_load + d_dict["withdrawal_max"]
end


# gpm_type = GPM.GasPowerModel{CRDWPGasModel, SOCWRPowerModel}
gpm_type = GasPowerModels.GasPowerModel{GasModels.CRDWPGasModel, PowerModels.DCPPowerModel}
weight=1.0
optimizer = JuMP.optimizer_with_attributes(() -> Gurobi.Optimizer(GRB_ENV), "LogToConsole" => 0)
result = GasPowerModels.solve_mld(data, gpm_type, GasPowerModels.build_mld, optimizer, weight)

[sum(l_dict["pg"] for (l,l_dict) in result["solution"]["it"]["pm"]["gen"]),sum(l_dict["pd"] for (l,l_dict) in result["solution"]["it"]["pm"]["load"]), sum(l_dict["pd"] for (l,l_dict) in pdata["load"]), result["active_power_served"]/pdata["baseMVA"]]



