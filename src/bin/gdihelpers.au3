#include-once

Func GetDC($hWnd,$_dll='user32.dll')
     Return DllCall($_dll,'handle','GetDC','handle',$hWnd)[0]
EndFunc 

Func ReleaseDC($hWnd,$hDC,$_dll='user32.dll')
     Return DllCall($_dll,'int','ReleaseDC','handle',$hWnd,'handle',$hDC)[0]
EndFunc

Func BitBlt($dst,$x,$y,$cx,$cy,$src,$x1,$y1,$rop,$_dll='gdi32.dll')
     Return DllCall($_dll,'bool','BitBlt','handle',$dst,'int',$x,'int',$y,'int',$cx,'int',$cy,'handle',$src,'int',$x1,'int',$y1,'dword',$rop)[0]
EndFunc

Func GetStockObject($i,$_dll='gdi32.dll')
     Return DllCall($_dll,'handle','GetStockObject','int',$i)[0]
EndFunc

Func SelectObject($hDC,$h,$_dll='gdi32.dll')
     Return DllCall($_dll,'handle','SelectObject','handle',$hDC,'handle',$h)[0]
EndFunc

Func SetDCPenColor($hDC,$color,$_dll='gdi32.dll')
     Return DllCall($_dll,'dword','SetDCPenColor','handle',$hDC,'dword',$color)[0]
EndFunc

Func CreatePen($style,$width,$color,$_dll='gdi32.dll')
     Return DllCall($_dll,'handle','CreatePen','int',$style,'int',$width,'dword',$color)[0]
EndFunc

Func Polyline($hDC,$apt,$cpt,$_dll='gdi32.dll')
     Return DllCall($_dll,'bool','Polyline','handle',$hDC,'struct*',$apt,'int',$cpt)[0]
EndFunc

Func SetPixel($hDC,$x,$y,$color,$_dll='gdi32.dll')
     Return DllCall($_dll,'dword','SetPixel','handle',$hDC,'int',$x,'int',$y,'dword',$color)[0]
EndFunc

Func CreateCompatibleDC($hDC,$_dll='gdi32.dll')
     Return DllCall($_dll,'handle','CreateCompatibleDC','handle',$hDC)[0]
EndFunc

Func CreateCompatibleBitmap($hDC,$cx,$cy,$_dll='gdi32.dll')
     Return DllCall($_dll,'handle','CreateCompatibleBitmap','handle',$hDC,'int',$cx,'int',$cy)[0]
EndFunc

Func DeleteDC($hDC,$_dll='gdi32.dll')
     Return DllCall($_dll,'bool','DeleteDC','handle',$hDC)[0]
EndFunc

Func DeleteObject($hObj,$_dll='gdi32.dll')
     Return DllCall($_dll,'bool','DeleteObject','handle',$hObj)[0]
EndFunc
