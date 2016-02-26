# Skcore contains the actual implementation of the Julia part of scikit-learn.
# It's a flat module, which simplifies the implementation.
# Sklearn defines the visible interface. This schema makes it easier
# change the public module structure.
module Skcore

using PyCall
using Utils 
using Parameters
using SymDict

include("sk_utils.jl")

@pyimport2 sklearn
@pyimport sklearn.base as sk_base

# These are the functions that should be implemented by estimators/transformers
api = [:fit!, :transform, :fit_transform!, :predict, :score_samples, :sample,
       :score, :decision_function, :clone, :set_params!, :get_params,
       :is_classifier, :is_pairwise]

# Not sure if we should export all the api
for f in api @eval(export $f) end

macro import_api()
    # I wish `importall ..` worked
    esc(:(begin $([Expr(:import, :., :., f) for f in api]...) end))
end

abstract BaseEstimator

# Note that I don't know the rationale for the `safe` argument - cstjean Feb2016
clone(py_model::PyObject) = sklearn.clone(py_model, safe=true)
is_classifier(py_model::PyObject) = sk_base.is_classifier(py_model)

is_pairwise(py_model) = false # global default - override for specific models
is_pairwise(py_model::PyObject) =
    haskey(py_model, "_pairwise") ? py_model[:_pairwise] : false

################################################################################

# Julia => Python
api_map = Dict(:decision_function => :decision_function,
               :fit! => :fit,
               :fit_transform! => :fit_transform,
               :predict => :predict,
               :score_samples => :score_samples,
               :sample => :sample,
               :score => :score,
               :transform => :transform,
               :set_params! => :set_params,
               :get_params => :get_params)

for (jl_fun, py_fun) in api_map
    @eval $jl_fun(py_model::PyObject, args...; kwargs...) =
        py_model[$(Expr(:quote, py_fun))](args...; kwargs...)
end

################################################################################

imported_python_modules =
    Dict(:LinearModels => :linear_model,
         :Datasets => :datasets,
         :Preprocessing => :preprocessing)

for (jl_module, py_module) in imported_python_modules
    @eval @pyimport sklearn.$py_module as $jl_module
end



include("pipeline.jl")
include("scorer.jl")
include("cross_validation.jl")
include("grid_search.jl")


end
