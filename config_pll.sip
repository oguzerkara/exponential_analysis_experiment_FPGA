set_global_assignment -entity "config_pll" -library "lib_config_pll" -name IP_TOOL_NAME "altera_pll"
set_global_assignment -entity "config_pll" -library "lib_config_pll" -name IP_TOOL_VERSION "22.1"
set_global_assignment -entity "config_pll" -library "lib_config_pll" -name IP_TOOL_ENV "mwpim"
set_global_assignment -library "lib_config_pll" -name SPD_FILE [file join $::quartus(sip_path) "config_pll.spd"]

set_global_assignment -library "lib_config_pll" -name MISC_FILE [file join $::quartus(sip_path) "config_pll_sim/config_pll.vho"]
