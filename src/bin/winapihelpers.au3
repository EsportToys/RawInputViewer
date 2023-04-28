#include-once
; here goes misc winapi functions not defined in dedicated files
; this lets me avoid having to include autoit's udfs
; CONVENTION:
; prefix underscore for custom instances of winapi function 
; no underscore for verbatim wrap of winapi function

Func QueryPerformanceCounter($_dll='kernel32.dll')
     Return DllCall($_dll,'bool','QueryPerformanceCounter','Int64*',Null)[1]
EndFunc

Func QueryPerformanceFrequency($_dll='kernel32.dll')
     Return DllCall($_dll,'bool','QueryPerformanceFrequency','Int64*',Null)[1]
EndFunc

Func GetDpiForWindow($hWnd, $_dll='user32.dll')
     Return DllCall($_dll, "uint", "GetDpiForWindow", "handle", $hWnd)[0]
EndFunc

Func SetCursor($hCursor=Null, $_dll='user32.dll')
     Return DllCall($_dll, "handle", "SetCursor", "handle", $hCursor)[0]
EndFunc

Func CreateIconIndirect($fIcon,$xHotspot,$yHotspot,$hbmMask,$hbmColor,$_dll='user32.dll')
     Local $iconinfo = DllStructCreate('bool fIcon;dword xHotspot;dword yHotspot;handle hbmMask;handle hbmColor;')
     $iconinfo.fIcon = $fIcon
     $iconinfo.xHotspot = $xHotspot
     $iconinfo.yHotspot = $yHotspot
     $iconinfo.hbmMask  = $hbmMask
     $iconinfo.hbmColor = $hbmColor
     Return DllCall($_dll,'handle','CreateIconIndirect','struct*',$iconinfo)[0]
EndFunc

Func DestroyCursor($hCursor, $_dll='user32.dll')
     Return DllCall($_dll,"bool","DestroyCursor","handle",$hCursor)[0]
EndFunc

Func GetClipCursor($_dll='user32.dll')
     Return DllCall($_dll,'bool','GetClipCursor','struct*',DllStructCreate('long left;long top;long right;long bottom;'))[1]
Endfunc

Func ClipCursor($rect,$_dll='user32.dll')
     Return DllCall($_dll,'bool','ClipCursor','struct*',$rect)[0]
EndFunc 

Func _FreeCursor($_dll='user32.dll')
     Return ClipCursor(Null,$_dll)
EndFunc

Func _TrapCursor($left,$top,$right,$bottom,$_dll='user32.dll')
     Local Static $rect = DllStructCreate('long;long;long;long;')
     DllStructSetData($rect,1,$left)
     DllStructSetData($rect,2,$top)
     DllStructSetData($rect,3,$right)
     DllStructSetData($rect,4,$bottom)
     Return ClipCursor($rect,$_dll)
EndFunc

Func _LockCursor($x,$y,$_dll='user32.dll')
     Return _TrapCursor($x,$y,$x+1,$y+1,$_dll)
EndFunc

Func _CenterCursor($left,$top,$right,$bottom,$_dll='user32.dll')
     Return _LockCursor(Int(($left+$right)/2),Int(($top+$bottom)/2),$_dll)
EndFunc

Func _LoadBigCursor($filepath,$_dll='user32.dll')
     Return _
     DllCall($_dll, "handle", "LoadImage", _
                    "handle", Null, _        ; hInstance null to load my own image
                       "str", $filepath, _
                      "uint", 2, _           ; type cursor
                       "int", 0, _           ; width zero to use the actual file width
                       "int", 0, _           ; height zero to use the actual file height
                      "uint", 0x00000010)[0] ; LR_LOADFROMFILE
EndFunc 

Func _GetPointerSpeed($_dll='user32.dll') 
     Return _
     DllCall($_dll, "bool",  "SystemParametersInfo", _
                    "uint",  0x0070, _
                    "uint",  0, _
                    "uint*", Null, _
                    "uint",  0)[3]
EndFunc

Func _GetPointerAccel($_dll='user32.dll')
     Return _
     DllCall($_dll, "bool",  "SystemParametersInfo", _
                    "uint",  0x0003, _
                    "uint",  0, _
                 "struct*",  DllStructCreate("uint thresh1;uint thresh2;uint accel;"), _
                    "uint",  0)[3]
EndFunc

Func _SetPointerSpeed($spd, $flag=0, $_dll='user32.dll')
     DllCall($_dll, "bool",  "SystemParametersInfo", _
                    "uint",  0x0071, _
                    "uint",  0, _
                    "uint",  $spd, _
                    "uint",  $flag)
EndFunc

Func _SetPointerAccel($acc, $flag=0, $_dll='user32.dll')
     DllCall($_dll, "bool",  "SystemParametersInfo", _
                    "uint",  0x0004, _
                    "uint",  0, _
                 "struct*",  $acc, _
                    "uint",  $flag)
EndFunc
