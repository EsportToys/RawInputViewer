Func CmdLineHandler($arrCmdLine)
     Switch $arrCmdLine[1]
#cs
       Case "GIDC_ARRIVAL"
            FileWrite($arrCmdLine[3], @CRLF & "==============" & @CRLF & " GIDC_ARRIVAL " & @CRLF & "==============" & @CRLF & GetConnectedRawinputDevicesInfoString($arrCmdLine[2]) & @CRLF)
            Exit
       Case "GIDC_REMOVAL"
            FileWrite($arrCmdLine[3], @CRLF & "==============" & @CRLF & " GIDC_REMOVAL " & @CRLF & "==============" & @CRLF & "Handle: 0x" & Hex($arrCmdLine[2],16) & @CRLF)
            Exit
#ce
       Case "HID_LIST_DISPLAY"
            initialize_i18n_strings($GLOBAL_OPTIONS_INI_PATH)
            CLI_DisplayDevices()
            Do
            Until GUIGetMsg()=$GUI_EVENT_CLOSE
            Exit
     EndSwitch
EndFunc

Func ProgramCommand($cmdstring) ; this would be a singleton handler for a quake-like console, with a string command interpreter. For now it's just a stub for returning ini options
    Local $cmd=CommandStringInterpreter($cmdstring)

    Local Static $demo_render_width, $demo_render_height
    Local Static $initialized=false

    Switch $cmd[0]
      Case "init_refresh"
           $demo_render_width  = IniRead($cmd[1],"Demo","width" ,640)
           $demo_render_height = IniRead($cmd[1],"Demo","height",480)
      Case "demo_render_width"
           if $cmd[1] = null then return $demo_render_width
      Case "demo_render_height"
           if $cmd[1] = null then return $demo_render_height
    EndSwitch
EndFunc

Func CommandStringInterpreter($cmdstring) ; just a stub for now, should be able to pass address later on and handle errors
     Local $arr=[$cmdstring,null]
     if $cmdstring=="init_refresh" then $arr[1]=$GLOBAL_OPTIONS_INI_PATH
     return $arr
EndFunc

Func CLI_DisplayDevices()
       Local $handle=GUICreate($i18n_deviceinfo_wintitle&$i18n_program_title_suffix,640,480,-1,-1,$WS_BORDER + $WS_SIZEBOX)
       Local $ctrledit = GUICtrlCreateEdit(GetConnectedRawinputDevicesInfoString(), 0, 0, 640, 480, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_AUTOHSCROLL + $WS_HSCROLL + $ES_READONLY)
       GUICtrlSetFont($ctrledit, 9, 0, 0, "Consolas")
       GUICtrlSetResizing($ctrledit, $GUI_DOCKBORDERS)
       GUISetIcon($GLOBAL_PROGRAM_ICON_PATH)
       GUISetState()
       Return $handle
EndFunc