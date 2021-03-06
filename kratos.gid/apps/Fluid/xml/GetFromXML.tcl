namespace eval Fluid::xml {
    # Namespace variables declaration
    variable dir
}

proc Fluid::xml::Init { } {
    # Namespace variables inicialization
    variable dir
    Model::InitVariables dir $Fluid::dir
    
    Model::getSolutionStrategies Strategies.xml
    Model::getElements Elements.xml
    Model::getMaterials Materials.xml
    Model::getNodalConditions NodalConditions.xml
    Model::getConstitutiveLaws ConstitutiveLaws.xml
    Model::getProcesses "../../Common/xml/Processes.xml"
    Model::getProcesses Processes.xml
    Model::getConditions Conditions.xml
    Model::getSolvers "../../Common/xml/Solvers.xml"
}

proc Fluid::xml::getUniqueName {name} {
    return ${::Fluid::prefix}${name}
}

proc Fluid::xml::CustomTree { args } {
    set root [customlib::GetBaseRoot]

    # Output control in output settings
    spdAux::SetValueOnTreeItem v time FLResults FileLabel
    spdAux::SetValueOnTreeItem v time FLResults OutputControlType

    # Drag in output settings
    if {[$root selectNodes "[spdAux::getRoute FLResults]/condition\[@n='Drag'\]"] eq ""} {
        gid_groups_conds::addF [spdAux::getRoute FLResults] include [list n Drag active 1 path {apps/Fluid/xml/Drag.spd}]
    }
    
    customlib::ProcessIncludes $::Kratos::kratos_private(Path)
    spdAux::parseRoutes

    # Nodal reactions in output settings
    if {[$root selectNodes "[spdAux::getRoute Results]/container\[@n='OnNodes'\]"] ne ""} {
        gid_groups_conds::addF "[spdAux::getRoute Results]/container\[@n='OnNodes'\]" value [list n REACTION pn "Reaction" v No values "Yes,No"]
    }
}

# Usage 
# Fluid::xml::CreateNewInlet Inlet {new false name Total} true "6*y*(1-y)"
proc Fluid::xml::CreateNewInlet { base_group_name {interval_data {new true name inlet1 ini 0 end "End"}} {uses_formula false} {value 10.0} {direction automatic_inwards_normal} {fluid_conditions_UN FLBC} {inlet_condition_name_base AutomaticInlet} } {
    # Fluid Inlet
    set nd $::Model::SpatialDimension
    set condtype line
    if {$nd eq "3D"} { set condtype surface }

    set fluidConditions [spdAux::getRoute $fluid_conditions_UN]
    set fluidInlet "$fluidConditions/condition\[@n='$inlet_condition_name_base$nd'\]"
    
    set interval_name [dict get $interval_data name] 
    if {[write::isBooleanTrue [dict get $interval_data new]]} {
        spdAux::CreateInterval $interval_name [dict get $interval_data ini] [dict get $interval_data end]

    }
    GiD_Groups create "$base_group_name//$interval_name"
    GiD_Groups edit state "$base_group_name//$interval_name" hidden
    spdAux::AddIntervalGroup $base_group_name "$base_group_name//$interval_name"
    set inletNode [customlib::AddConditionGroupOnXPath $fluidInlet "$base_group_name//$interval_name"]
    $inletNode setAttribute ov $condtype
    if {[write::isBooleanTrue $uses_formula]} {
        set function $value
        set props [list ByFunction Yes function_modulus $function direction $direction Interval $interval_name]
    } else {
        set props [list ByFunction No modulus $value direction $direction Interval $interval_name]
    }
    foreach {prop val} $props {
        set propnode [$inletNode selectNodes "./value\[@n = '$prop'\]"]
        if {$propnode ne "" } {
            $propnode setAttribute v $val
        } else {
            W "Warning - Couldn't find property Inlet $prop"
        }
    }
    
}

Fluid::xml::Init
