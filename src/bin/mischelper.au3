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

Func PointerMultiplier($spd,$acc,$dpi)
     Return ( $acc ? $spd/10 : ( $spd<4 ? BitShift(1,-$spd)/64 : 1 + ($spd-10)/BitShift(8,Int($spd/10.5)) ) ) * $dpi/96
EndFunc