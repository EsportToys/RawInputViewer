Func initialize_i18n_strings($inipath)
     Local Const $lang = IniRead($inipath,"Option","lang","en")
     Local Const $path = @ScriptDir & "\assets\i18n\i18n_" & $lang & ".ini"
     Local Enum $key, $val
     Local Enum $ENUM_FIRST_ITEM_i18n=-1, _
                $program_title_suffix, _
                $inactive_status, _
                $active_status, _
                $demorunning_status, _
                $suspended_status, _
                $clicktostart_title, _
                $devicechange_title, _
                $deviceinfo_wintitle, _
                $demo_wintitle, _
                $active_buttontext, _
                $inactive_buttontext, _
                $suspend_buttontext, _
                $resume_buttontext, _
                $devices_buttontext, _
                $demo_buttontext, _
                $ENUM_NUM_ITEMS_i18n

     Local $default[$ENUM_NUM_ITEMS_i18n][2]
     $default[$program_title_suffix][$key] = "program_title_suffix"
     $default[$inactive_status][$key] = "inactive_status"
     $default[$active_status][$key] = "active_status"
     $default[$demorunning_status][$key] = "demorunning_status"
     $default[$suspended_status][$key] = "suspended_status"
     $default[$clicktostart_title][$key] = "clicktostart_title"
     $default[$devicechange_title][$key] = "devicechange_title"
     $default[$deviceinfo_wintitle][$key] = "deviceinfo_wintitle"
     $default[$demo_wintitle][$key] = "demo_wintitle"
     $default[$active_buttontext][$key] = "active_buttontext"
     $default[$inactive_buttontext][$key] = "inactive_buttontext"
     $default[$suspend_buttontext][$key] = "suspend_buttontext"
     $default[$resume_buttontext][$key] = "resume_buttontext"
     $default[$devices_buttontext][$key] = "devices_buttontext"
     $default[$demo_buttontext][$key] = "demo_buttontext"

     $default[$program_title_suffix][$val] = " - RawInputViewer"
     $default[$inactive_status][$val] = "Inactive"
     $default[$active_status][$val] = "ACTIVE"
     $default[$demorunning_status][$val] = "DEMO RUNNING"
     $default[$suspended_status][$val] = "COLLECTION SUSPENDED"
     $default[$clicktostart_title][$val] = "Click Button to Start"
     $default[$devicechange_title][$val] = "DEVICECHANGE"
     $default[$deviceinfo_wintitle][$val] = "Devices List"
     $default[$demo_wintitle][$val] = "Demo"
     $default[$active_buttontext][$val] = "ACTIVE"
     $default[$inactive_buttontext][$val] = "Inactive"
     $default[$suspend_buttontext][$val] = "Suspend"
     $default[$resume_buttontext][$val] = "&Resume"
     $default[$devices_buttontext][$val] = "Devices"
     $default[$demo_buttontext][$val] = "Demo"

     Local $var, $str
     For $i=0 to $ENUM_NUM_ITEMS_i18n-1
         $var = "i18n_" & $default[$i][$key]
         $str = IniRead($path,$lang,$default[$i][$key],$default[$i][$val])
         Assign($var, $str, 2)
     Next
EndFunc
