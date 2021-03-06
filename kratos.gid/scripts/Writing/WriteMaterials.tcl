
proc write::processMaterials { {alt_path ""} {last_assigned_id -1}} {
    variable mat_dict

    set parts [GetConfigurationAttribute parts_un]
    set materials_un [GetConfigurationAttribute materials_un]
    set root [customlib::GetBaseRoot]

    set xp1 "[spdAux::getRoute $parts]/group"
    if {$alt_path ne ""} {
        set xp1 $alt_path
    }
    set xp2 ".//value\[@n='Material']"

    set material_number [expr {$last_assigned_id == -1 ? [llength [dict keys $mat_dict] ] : $last_assigned_id }]

    foreach gNode [$root selectNodes $xp1] {
        set nodeApp [spdAux::GetAppIdFromNode $gNode]
        set group [$gNode getAttribute n]
        set valueNode [$gNode selectNodes $xp2]
        set material_name "material $material_number"
        if { ![dict exists $mat_dict $group] } {
            incr material_number
            set mid $material_number

            dict set mat_dict $group MID $material_number
            dict set mat_dict $group APPID $nodeApp

            set claws [get_domnode_attribute [$gNode selectNodes ".//value\[@n = 'ConstitutiveLaw'\]"] values]
            set claw [get_domnode_attribute [$gNode selectNodes ".//value\[@n = 'ConstitutiveLaw'\]"] v]
            set const_law [Model::getConstitutiveLaw $claw]
            if {$const_law ne ""} {
                set output_type [$const_law getOutputMode]

                if {$output_type eq "Parameters"} {
                    set s1 [$gNode selectNodes ".//value"]
                } else {
                    set real_material_name [get_domnode_attribute $valueNode v]
                    set xp3 "[spdAux::getRoute $materials_un]/blockdata\[@n='material' and @name='$real_material_name']"
                    set matNode [$root selectNodes $xp3]
                    set s1 [join [list [$gNode selectNodes ".//value"] [$matNode selectNodes ".//value"]]]
                }
            } else {
                set s1 [$gNode selectNodes ".//value"]
            }

            foreach valueNode $s1 {
                write::forceUpdateNode $valueNode
                set name [$valueNode getAttribute n]
                set state [get_domnode_attribute $valueNode state]
                if {$state ne "hidden" || $name eq "ConstitutiveLaw"} {
                    # All the introduced values are translated to 'm' and 'kg' with the help of this function
                    set value [gid_groups_conds::convert_value_to_default $valueNode]

                    # if {[string is double $value]} {
                        #     set value [format "%13.5E" $value]
                        # }

                    dict set mat_dict $group $name $value
                }
            }
        }
    }
}

proc write::writeMaterials { {appid ""} {const_law_write_name ""}} {
    variable mat_dict
    variable current_mdpa_indent_level

    set exclusionList [list "MID" "APPID" "Material" "Element"]
    if {$const_law_write_name eq ""} {lappend exclusionList "ConstitutiveLaw"}

    # We print all the material data directly from the saved dictionary
    foreach material [dict keys $mat_dict] {
        set matapp [dict get $mat_dict $material APPID]
        if {$appid eq "" || $matapp in $appid} {
            set s [mdpaIndent]
            WriteString "${s}Begin Properties [dict get $mat_dict $material MID]"
            incr current_mdpa_indent_level
            set s [mdpaIndent]
            foreach prop [dict keys [dict get $mat_dict $material] ] {
                if {$prop ni $exclusionList} {
                    if {${prop} eq "ConstitutiveLaw"} {
                        set propname $const_law_write_name
                        set value [[Model::getConstitutiveLaw [dict get $mat_dict $material $prop]] getKratosName]
                    } else {
                        set propname [expr { ${prop} eq "ConstitutiveLaw" ? $const_law_write_name : $prop}]
                        set value [dict get $mat_dict $material $prop]
                    }
                    WriteString "${s}$propname $value"
                }
            }
            incr current_mdpa_indent_level -1
            set s [mdpaIndent]
            WriteString "${s}End Properties"
            WriteString ""
        }
    }
}