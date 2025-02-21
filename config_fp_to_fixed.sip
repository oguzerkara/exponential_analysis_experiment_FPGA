set_global_assignment -entity "config_fp_to_fixed" -library "lib_config_fp_to_fixed" -name IP_TOOL_NAME "altera_fp_functions"
set_global_assignment -entity "config_fp_to_fixed" -library "lib_config_fp_to_fixed" -name IP_TOOL_VERSION "22.1"
set_global_assignment -entity "config_fp_to_fixed" -library "lib_config_fp_to_fixed" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_config_fp_to_fixed" -name SPD_FILE [file join $::quartus(sip_path) "config_fp_to_fixed.spd"]

set_global_assignment -library "lib_config_fp_to_fixed" -name MISC_FILE [file join $::quartus(sip_path) "config_fp_to_fixed_sim/dspba_library_package.vhd"]
set_global_assignment -library "lib_config_fp_to_fixed" -name MISC_FILE [file join $::quartus(sip_path) "config_fp_to_fixed_sim/dspba_library.vhd"]
set_global_assignment -library "lib_config_fp_to_fixed" -name MISC_FILE [file join $::quartus(sip_path) "config_fp_to_fixed_sim/config_fp_to_fixed.vhd"]
