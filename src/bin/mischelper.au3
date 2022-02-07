; from https://www.autoitscript.com/forum/topic/168698-changing-a-windows-icon/?do=findComment&comment=1233266
Func _WinSetIcon($hWnd, $sFile, $iIndex = 0)
    Local $tIcons = DllStructCreate("ptr Data")
    DllCall("shell32.dll", "uint", "ExtractIconExW", "wstr", $sFile, "int", $iIndex, "struct*", 0, "struct*", $tIcons, "uint", 1)
    If @error Then Return SetError(1, 0, 0)
    Local $hIcon = DllStructGetData($tIcons, "Data")
   _SendMessage($hWnd, 0x0080, 1, $hIcon ) ;$WM_SETICON = 0x0080
   _WinAPI_DestroyIcon($hIcon)
   Return 1
EndFunc

; from https://www.autoitscript.com/forum/topic/183294-disable-right-click-on-control/?do=findComment&comment=1316532
Func EditCallback( $hWnd, $iMsg, $wParam, $lParam, $iSubclassId, $pData )
  ; If $iMsg <> $WM_RBUTTONUP then call next function in subclass chain (this forwards messages to Edit control)
  If $iMsg <> $WM_RBUTTONUP Then Return DllCall( "comctl32.dll", "lresult", "DefSubclassProc", "hwnd", $hWnd, "uint", $iMsg, "wparam", $wParam, "lparam", $lParam )[0]
  Return 0 ; If $iMsg = $WM_RBUTTONUP then cancel the message by returning 0
EndFunc

Func _CleanupFileName($input)
     $input = StringReplace( $input, '?', '' )
     $input = StringReplace( $input, ':', '-' )
     $input = StringReplace( $input, '*', '' )
     $input = StringReplace( $input, '|', '' )
     $input = StringReplace( $input, '/', '-' )
     $input = StringReplace( $input, '\', '' )
     $input = StringReplace( $input, '<', '' )
     $input = StringReplace( $input, '>', '' )
     $input = StringReplace( $input, ' ', '_' )
     Return $input
EndFunc

Func BackupPointerSpeedAndAccel(ByRef $array)
     Local $struct = _GetPointerAccel()
     $array[0] = _GetPointerSpeed()
     $array[1] = DllStructGetData($struct,"accel")
     $array[2] = DllStructGetData($struct,"thresh1")
     $array[3] = DllStructGetData($struct,"thresh2")
EndFunc

Func RestorePointerSpeedAndAccel(ByRef $array)
     Local $struct = DllStructCreate("uint thresh1;uint thresh2;uint accel")
                     DllStructSetData($struct,"thresh2",$array[3])
                     DllStructSetData($struct,"thresh1",$array[2])
                     DllStructSetData($struct,"accel",$array[1])
     _SetPointerSpeed($array[0])
     _SetPointerAccel($struct)
EndFunc

Func DisablePointerSpeedAndAccel()
     Local $struct = DllStructCreate("uint thresh1;uint thresh2;uint accel")
                     DllStructSetData($struct,"thresh1",0)
                     DllStructSetData($struct,"thresh2",0)
                     DllStructSetData($struct,"accel",0)
     _SetPointerSpeed(10)
     _SetPointerAccel($struct)
EndFunc

Func _GetPointerSpeed()
     Local $struct = DllStructCreate("uint speed")    
     DllCall("user32.dll", "none", "SystemParametersInfo", _
                           "uint",  0x0070, _
                           "uint",  0, _
                           "ptr" ,  DllStructGetPtr($struct), _
                           "uint",  0)
     return DllStructGetData($struct,"speed")
EndFunc

Func _GetPointerAccel()
     Local $struct = DllStructCreate("uint thresh1;uint thresh2;uint accel")
     DllCall("user32.dll", "none", "SystemParametersInfo", _
                           "uint",  0x0003, _
                           "uint",  0, _
                           "ptr" ,  DllStructGetPtr($struct), _
                           "uint",  0)
     return $struct
EndFunc

Func _SetPointerSpeed($val, $flag=0)
     DllCall("user32.dll", "none", "SystemParametersInfo", _
                           "uint",  0x0071, _
                           "uint",  0, _
                           "uint",  $val, _
                           "uint",  $flag)
EndFunc

Func _SetPointerAccel($struct, $flag=false)
     DllCall("user32.dll", "none", "SystemParametersInfo", _
                           "uint",  0x0004, _
                           "uint",  0, _
                           "ptr" ,  DllStructGetPtr($struct), _
                           "uint",  $flag)
EndFunc