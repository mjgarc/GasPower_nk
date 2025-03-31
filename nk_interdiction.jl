# The following are necessary to use the run_deterministic function from stochastic_nk.
using JuMP
import MathOptInterface as MOI
import PowerModels
import Gurobi
const GRB_ENV = Gurobi.Env()
include("stochastic_nk/src/cliparser.jl")
include("stochastic_nk/src/types.jl")
include("stochastic_nk/src/data_helper.jl")
include("stochastic_nk/src/common/gas-ls.jl")
include("stochastic_nk/src/GasDeterministic/run.jl")
# include("stochastic_nk/src/deterministic/run.jl")

function run_gas_interdiction(
    gdata::Dict{String,Any};
    budget::Int64 = 1,
)
    args = Dict{String,Any}(
        "timeout" => 86400,
        "optimality_gap" => 0.01,
        "budget" => budget,
        "inner_solver" => "gurobi",
        "use_separate_budgets" => false,
    )
    validate_parameters(args; skip_path_validation = false)
    results = run_gas_deterministic(args, gdata)
end
