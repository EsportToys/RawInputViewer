#include <WinAPISys.au3>

#cs
Used UDFs:
_WinAPI_EnumRawInputDevices
_WinAPI_GetRawInputDeviceInfo
_WinAPI_CreateFile
_WinAPI_CloseHandle

Used UDF Constants:
$RIDI_DEVICENAME
$RIDI_DEVICEINFO
$OPEN_EXISTING
$FILE_SHARE_READ
$FILE_SHARE_WRITE
#ce

Func CheckUniqueUsageAndAdd(ByRef $arr, $page, $id)
     Local $total=UBound($arr,1)
     For $i=0 to $total-1
         If $arr[$i][0]=$page And $arr[$i][1]=$id Then Return
     Next
     $total += 1
     ReDim $arr[$total][2]
     $arr[$total-1][0]=$page
     $arr[$total-1][1]=$id
EndFunc

Func GetConnectedRawinputDevicesUsages($devflag) ; called by RawinputStateController to return a 2D array for registration processing
     ; UsagePage 0x01 = generic desktop controls; Usage 0x02 = mouse
     ; UsagePage 0x01 = generic desktop controls; Usage 0x06 = keyboard
     Local $retArr[0][2], $deviceList = _WinAPI_EnumRawInputDevices()
     If BitAND($devflag,1) Then CheckUniqueUsageAndAdd($retArr, 0x01, 0x02)
     If BitAND($devflag,2) Then CheckUniqueUsageAndAdd($retArr, 0x01, 0x06)
     If BitAND($devflag,4) AND IsArray($deviceList) Then
        Local $numDevices=$deviceList[0][0], $devInf=DllStructCreate('dword Size;dword Type;struct;dword VendorId;dword ProductId;dword VersionNumber;ushort UsagePage;ushort Usage;endstruct;dword Unused[2]')
        Local $usagepage, $usageid
        For $i=1 to $numDevices
            If $deviceList[$i][1]=2 Then
               If _WinAPI_GetRawInputDeviceInfo($deviceList[$i][0], $devInf, DllStructGetSize($devInf), $RIDI_DEVICEINFO ) Then
                  $usagepage = DllStructGetData($devInf, 'UsagePage')
                  $usageid   = DllStructGetData($devInf, 'Usage')
                  CheckUniqueUsageAndAdd($retArr, $usagepage, $usageid)
               EndIf
            EndIf
        Next
     EndIf
     Return $retArr
EndFunc

Func GetConnectedRawinputDevicesInfoString($matchHandleFilter=null)
     Local $tText
     Local $list = _WinAPI_EnumRawInputDevices()
  If IsArray($list) Then
     Switch $matchHandleFilter
       Case Null
            Local  $device_info_string = ''
            For $i = 1 To $list[0][0]
                $device_info_string = $device_info_string & GetDeviceInfoString($list[$i][0],$list[$i][1]) & @CRLF
            Next
            Return $device_info_string
       Case Else
            For $i = 1 To $list[0][0]
                If ($matchHandleFilter=$list[$i][0]) Then Return GetDeviceInfoString($list[$i][0],$list[$i][1])
            Next
     EndSwitch
  EndIf
EndFunc

Func GetDeviceInfoString($handle, $type)
     Local Const $hidtable = @ScriptDir & '\assets\hidusagetable.ini'
     Local $tName, $tText = DllStructCreate('wchar[256]')
     Local $device_info_string = 'Handle: ' & $handle & @CRLF

     If _WinAPI_GetRawInputDeviceInfo($handle, $tText, DllStructGetSize($tText), $RIDI_DEVICENAME) Then
        Local $name = DllStructGetData($tText, 1)
        $device_info_string = $device_info_string & $name & @CRLF

        Local $HIDHandle = _WinAPI_CreateFile( $name , $OPEN_EXISTING , 0 , BitOR($FILE_SHARE_READ,$FILE_SHARE_WRITE) , Null , Null )
        If $HIDHandle Then
           $tName = DllStructCreate('struct;ULONG Size; USHORT VendorID; USHORT ProductID; USHORT VersionNumber;endstruct')
                    DllStructSetData($tName, 'Size', DllStructGetSize($tName))
                    DllCall ( "Hid.dll", 'boolean', 'HidD_GetAttributes', _
                                         'handle' , $HIDHandle , _
                                         'struct*', $tName )
           Local $s_vend = 'VID_' & Hex(DllStructGetData($tName, 'VendorID'),4)
           Local $s_prod = 'PID_' & Hex(DllStructGetData($tName, 'ProductID'),4)
           Local $s_revi = 'REV_' & Hex(DllStructGetData($tName, 'VersionNumber'),4)

           $tName = DllStructCreate('wchar[126]')
                    DllCall ( "Hid.dll", 'boolean', 'HidD_GetManufacturerString', _
                                         'handle' , $HIDHandle , _
                                         'struct*', $tName, _
                                         'ulong'  , DllStructGetSize($tName) )
           if DllStructGetData($tName, 1) then $s_vend = $s_vend & ' (' & DllStructGetData($tName, 1) & ')'

                    DllCall ( "Hid.dll", 'boolean', 'HidD_GetProductString', _
                                         'handle' , $HIDHandle , _
                                         'struct*', $tName, _
                                         'ulong'  , DllStructGetSize($tName) )
           if DllStructGetData($tName, 1) then $s_prod = $s_prod & ' (' & DllStructGetData($tName, 1) & ')'

           $device_info_string = $device_info_string & _
                                  '  Vendor:  ' & $s_vend & @CRLF & _
                                  '  Product: ' & $s_prod & @CRLF & _
                                  '  Version: ' & $s_revi & @CRLF

           Local $serial = DllCall ( "Hid.dll", 'boolean', 'HidD_GetSerialNumberString', _
                                                'handle' , $HIDHandle , _
                                                'struct*', $tName, _
                                                'ulong'  , DllStructGetSize($tName) )
           if $serial[0] then $device_info_string = $device_info_string & '  Serial#: ' & DllStructGetData($tName, 1) & @CRLF
        EndIf
        _WinAPI_CloseHandle($HIDHandle)
     EndIf

     Switch $type
       Case 0
            Local Const $mouseRIDstruct='dword Size;dword Type;struct;dword Id;dword NumberOfButtons;dword SampleRate;int HasHorizontalWheel;endstruct;dword Unused[2];'
            Local $devInf = DllStructCreate($mouseRIDstruct) ; $tagRID_INFO_MOUSE in WinAPISys.au3 has a typo 
            If _WinAPI_GetRawInputDeviceInfo($handle, $devInf, DllStructGetSize($devInf), $RIDI_DEVICEINFO ) Then
               $device_info_string = $device_info_string & _
                                  '      HID Type:   ' & _deviceType(DllStructGetData($devInf, 'Type'))                                         & @CRLF & _
                                  '      Id:         ' & '0x' & Hex(DllStructGetData($devInf, 'Id'),4) & _mouseIdType(DllStructGetData($devInf, 'Id')) & @CRLF & _
                                  '      Buttons:    ' & DllStructGetData($devInf, 'NumberOfButtons')                                           & @CRLF & _
                                  '      SampleRate: ' & DllStructGetData($devInf, 'SampleRate')                                                & @CRLF & _
                                  '      HorWheel:   ' & DllStructGetData($devInf, 'HasHorizontalWheel')                                        & @CRLF 
            EndIf
       Case 1
            Local Const $keyboardRIDstruct='dword Size;dword Type;struct;dword KbType;dword KbSubType;dword KeyboardMode;dword NumberOfFunctionKeys;dword NumberOfIndicators;dword NumberOfKeysTotal;endstruct'
            Local $devInf = DllStructCreate($keyboardRIDstruct) ; $tagRID_INFO_KEYBOARD in WinAPISys.au3 has a typo

            If _WinAPI_GetRawInputDeviceInfo($handle, $devInf, DllStructGetSize($devInf), $RIDI_DEVICEINFO ) Then
               $device_info_string = $device_info_string & _
                                  '      HID Type:   ' & _deviceType(DllStructGetData($devInf, 'Type'))                                            & @CRLF & _
                                  '      KbType:     ' & '0x' & Hex(DllStructGetData($devInf, 'KbType'),2) & _kbType(DllStructGetData($devInf, 'KbType')) & @CRLF & _
                                  '      KbSubType:  ' & '0x' & Hex(DllStructGetData($devInf, 'KbSubType'),2)                                             & @CRLF & _
                                  '      ScanMode:   ' & DllStructGetData($devInf, 'KeyboardMode')                                                 & @CRLF & _
                                  '      FuncKeys:   ' & DllStructGetData($devInf, 'NumberOfFunctionKeys')                                         & @CRLF & _
                                  '      Indicators: ' & DllStructGetData($devInf, 'NumberOfIndicators')                                           & @CRLF & _
                                  '      TotalKeys:  ' & DllStructGetData($devInf, 'NumberOfKeysTotal')                                            & @CRLF 
            EndIf 
       Case 2
            Local Const $hidRIDstruct='dword Size;dword Type;struct;dword VendorId;dword ProductId;dword VersionNumber;ushort UsagePage;ushort Usage;endstruct;dword Unused[2]'
            Local $devInf = DllStructCreate($hidRIDstruct) ; $tagRID_INFO_HID in WinAPISys.au3 has a typo

            If _WinAPI_GetRawInputDeviceInfo($handle, $devInf, DllStructGetSize($devInf), $RIDI_DEVICEINFO ) Then
               $device_info_string = $device_info_string & _
                                  '      HID Type:  ' & _deviceType(DllStructGetData($devInf, 'Type'))                                                         & @CRLF & _
                                  '      VendorID:  ' & Hex(DllStructGetData($devInf, 'VendorId'),4)                                                           & @CRLF & _
                                  '      ProductID: ' & Hex(DllStructGetData($devInf, 'ProductId'),4)                                                          & @CRLF & _
                                  '      Revision:  ' & Hex(DllStructGetData($devInf, 'VersionNumber'),4)                                                      & @CRLF & _
                                  '      UsagePage: ' & _HIDUsageString($hidtable, DllStructGetData($devInf, 'UsagePage'))                                     & @CRLF & _
                                  '      UsageID:   ' & _HIDUsageString($hidtable, DllStructGetData($devInf, 'UsagePage'), DllStructGetData($devInf, 'Usage')) & @CRLF 
            EndIf
     EndSwitch
     Return $device_info_string
; code adapted from https://www.autoitscript.com/forum/topic/190157-how-can-i-use-_winapi_getrawinputdeviceinfo-to-get-hid-device-info/?do=findComment&comment=1364904
; https://stackoverflow.com/questions/12656236/how-to-get-human-readable-name-for-rawinput-hid-device
; https://docs.microsoft.com/en-us/windows-hardware/drivers/hid/hidclass-hardware-ids-for-top-level-collections
; https://stackoverflow.com/questions/51513337/is-the-usb-instance-id-on-windows-unique-for-a-device
; device interface id = device instance id + device interface class guid
;                       device instance id = device id + instance specific id
EndFunc


Func _HIDUsageString($hidtable, $usagepage, $usageid=Null)
     Local $retStr       = ( $usageid=Null ? Hex($usagepage,4) : Hex($usageid,4) )
     Local $usagepageStr =                   Hex($usagepage,4)
     Local $usageidStr   = ( $usageid=Null ? 'page'            : Hex($usageid,4) )
     Local $friendlyname = IniRead($hidtable, $usagepageStr, $usageidStr, '')
     If $friendlyname Then 
        $retStr = $retStr & ' (' & $friendlyname & ')'
     ElseIf BitAnd(0xFF00,$usagepage) Then
        $retStr = $retStr & ' (VENDOR-DEFINED)'
     EndIf
     return $retStr
EndFunc

Func _deviceType($dwType)
     Switch $dwType
       Case 0
            return $dwType & ' (RIM_TYPEMOUSE)'
       Case 1
            return $dwType & ' (RIM_TYPEKEYBOARD)'
       Case 2
            return $dwType & ' (RIM_TYPEHID)'
     EndSwitch
EndFunc

Func _mouseIdType($dwId)
      Local $str = ''
            If BitAND($dwID,0x0080) Then $str = $str & ' (MOUSE_HID_HARDWARE)'
            If BitAND($dwID,0x0100) Then $str = $str & ' (WHEELMOUSE_HID_HARDWARE)'
            If BitAND($dwID,0x8000) Then $str = $str & ' (HORIZONTAL_WHEEL_PRESENT)'
     Return $str
EndFunc

Func _kbType($kbType)
      Local $str = ''  
     Switch $kbType
       Case 0x4
            $str = ' (Enhanced 101- or 102-key keyboards and compatibles)'
       Case 0x7
            $str = ' (Japanese Keyboard)'
       Case 0x8
            $str = ' (Korean Keyboard)'
       Case 0x51
            $str = ' (Unknown type or HID keyboard)'
     EndSwitch
     Return $str
EndFunc

Func _usFlagsMouse($usFlags)
      Local $str = ''
            If not $usFlags then return ' (MOUSE_MOVE_RELATIVE)'
            If BitAND($usFlags,1) Then $str = $str & ' (MOUSE_MOVE_ABSOLUTE)'
            If BitAND($usFlags,2) Then $str = $str & ' (MOUSE_VIRTUAL_DESKTOP)'
            If BitAND($usFlags,4) Then $str = $str & ' (MOUSE_ATTRIBUTES_CHANGED)'
            If BitAND($usFlags,8) Then $str = $str & ' (MOUSE_MOVE_NOCOALESCE)' 
     Return $str

; (Windows Vista and later) WM_MOUSEMOVE notification messages will not be coalesced. 
; By default, these messages are coalesced. 
; For more information about WM_MOUSEMOVE notification messages, see the Microsoft Software Development Kit (SDK) documentation

EndFunc

Func _usFlagsKeyboard($usFlags)
      Local $str = ''
            If not $usFlags then 
               return ' (RI_KEY_MAKE)'
            ElseIf $usFlags == 255 then
               return ' (KEYBOARD_OVERRUN_MAKE_CODE)'
            EndIf
            If BitAND($usFlags,16) Then $str = $str & ' (RI_KEY_TERMSRV_SHADOW)' 
            If BitAND($usFlags,8)  Then $str = $str & ' (RI_KEY_TERMSRV_SET_LED)' 
            If BitAND($usFlags,4)  Then $str = $str & ' (RI_KEY_E1)'
            If BitAND($usFlags,2)  Then $str = $str & ' (RI_KEY_E0)'
            If BitAND($usFlags,1)  Then $str = $str & ' (RI_KEY_BREAK)'
     Return $str
EndFunc

Func _usButtonFlags($usButtonFlags) ; recursive since there's tons of flags to check, faster to group by pure cases and else cases call recursively
      Local $str = ''
     Switch $usButtonFlags
       Case 0
            $str = ''
       Case 1
            $str = ' (+MB1)'
       Case 2
            $str = ' (-MB1)'
       Case 4
            $str = ' (+MB2)'
       Case 8
            $str = ' (-MB2)'
       Case 16
            $str = ' (+MB3)'
       Case 32
            $str = ' (-MB3)'
       Case 64
            $str = ' (+MB4)'
       Case 128
            $str = ' (-MB4)'
       Case 256
            $str = ' (+MB5)'
       Case 512
            $str = ' (-MB5)'
       Case 1024
            $str = ' (WHEEL)'
       Case 2048
            $str = ' (HWHEEL)'
       Case Else
            Local $i, $j = 1
            For $i = 0 to 11
                $str = $str & _usButtonFlags(BitAND($j, $usButtonFlags))
                $j = $j*2
            Next
     EndSwitch
     Return $str
EndFunc

Func _uiMessage($uiMessage) ; there are 65536 possible WM_* Windows Messages, only gonna include those relevant to keyboards
      Local $str = ''
     Switch $uiMessage
       Case 256 ; 0x0100
            $str = ' (WM_KEYDOWN)'
       Case 257 ; 0x0101
            $str = ' (WM_KEYUP)'
       Case 260 ; 0x0104
            $str = ' (WM_SYSKEYDOWN)'
       Case 261 ; 0x0105
            $str = ' (WM_SYSKEYUP)'
     EndSwitch
     Return $str
EndFunc

Func _usVkey($usVkey)
      Local $str = ''
     Switch $usVkey
       Case 0x01
            $str = ' (LBUTTON)'
       Case 0x02
            $str = ' (RBUTTON)'
       Case 0x03
            $str = ' (CANCEL)'
       Case 0x04
            $str = ' (MBUTTON)'
       Case 0x05
            $str = ' (XBUTTON1)'
       Case 0x06
            $str = ' (XBUTTON2)'
; 0x07 is undefined
       Case 0x08
            $str = ' (BACKSPACE)'
       Case 0x09
            $str = ' (TAB)'
; 0x0A to 0x0B are undefined
       Case 0x0C
            $str = ' (CLEAR)'
       Case 0x0D
            $str = ' (ENTER)'
; 0x0E to 0x0F are undefined
       Case 0x10
            $str = ' (SHIFT)'
       Case 0x11
            $str = ' (CTRL)'
       Case 0x12
            $str = ' (ALT)'
       Case 0x13
            $str = ' (PAUSE)'
       Case 0x14
            $str = ' (CAPSLOCK)'
       Case 0x15
            $str = ' (KANA)'
       Case 0x16
            $str = ' (IME_ON)'
       Case 0x17
            $str = ' (JUNJA)'
       Case 0x18
            $str = ' (FINAL)'
       Case 0x19
            $str = ' (KANJI)'
       Case 0x1A
            $str = ' (IME_OFF)'
       Case 0x1B
            $str = ' (ESC)'
       Case 0x1C
            $str = ' (CONVERT)'
       Case 0x1D
            $str = ' (NONCONVERT)'
       Case 0x1E
            $str = ' (ACCEPT)'
       Case 0x1F
            $str = ' (MODECHANGE)'
       Case 0x20
            $str = ' (SPACE)'
       Case 0x21
            $str = ' (PAGEUP)'
       Case 0x22
            $str = ' (PAGEDOWN)'
       Case 0x23
            $str = ' (END)'
       Case 0x24
            $str = ' (HOME)'
       Case 0x25
            $str = ' (LEFT)'
       Case 0x26
            $str = ' (UP)'
       Case 0x27
            $str = ' (RIGHT)'
       Case 0x28
            $str = ' (DOWN)'
       Case 0x29
            $str = ' (SELECT)'
       Case 0x2A
            $str = ' (PRINT)'
       Case 0x2B
            $str = ' (EXECUTE)'
       Case 0x2C
            $str = ' (PRTSCN)'
       Case 0x2D
            $str = ' (INSERT)'
       Case 0x2E
            $str = ' (DELETE)'
       Case 0x2F
            $str = ' (HELP)'
       Case 0x30
            $str = ' (0)'
       Case 0x31
            $str = ' (1)'
       Case 0x32
            $str = ' (2)'
       Case 0x33
            $str = ' (3)'
       Case 0x34
            $str = ' (4)'
       Case 0x35
            $str = ' (5)'
       Case 0x36
            $str = ' (6)'
       Case 0x37
            $str = ' (7)'
       Case 0x38
            $str = ' (8)'
       Case 0x39
            $str = ' (9)'
; 0x3A to 0x40 are undefined
       Case 0x41
            $str = ' (A)'
       Case 0x42
            $str = ' (B)'
       Case 0x43
            $str = ' (C)'
       Case 0x44
            $str = ' (D)'
       Case 0x45
            $str = ' (E)'
       Case 0x46
            $str = ' (F)'
       Case 0x47
            $str = ' (G)'
       Case 0x48
            $str = ' (H)'
       Case 0x49
            $str = ' (I)'
       Case 0x4A
            $str = ' (J)'
       Case 0x4B
            $str = ' (K)'
       Case 0x4C
            $str = ' (L)'
       Case 0x4D
            $str = ' (M)'
       Case 0x4E
            $str = ' (N)'
       Case 0x4F
            $str = ' (O)'
       Case 0x50
            $str = ' (P)'
       Case 0x51
            $str = ' (Q)'
       Case 0x52
            $str = ' (R)'
       Case 0x53
            $str = ' (S)'
       Case 0x54
            $str = ' (T)'
       Case 0x55
            $str = ' (U)'
       Case 0x56
            $str = ' (V)'
       Case 0x57
            $str = ' (W)'
       Case 0x58
            $str = ' (X)'
       Case 0x59
            $str = ' (Y)'
       Case 0x5A
            $str = ' (Z)'
       Case 0x5B
            $str = ' (LWIN)'
       Case 0x5C
            $str = ' (RWIN)'
       Case 0x5D
            $str = ' (APPS)'
; 0x5E is reserved
       Case 0x5F
            $str = ' (SLEEP)'
       Case 0x60
            $str = ' (NUMPAD0)'
       Case 0x61
            $str = ' (NUMPAD1)'
       Case 0x62
            $str = ' (NUMPAD2)'
       Case 0x63
            $str = ' (NUMPAD3)'
       Case 0x64
            $str = ' (NUMPAD4)'
       Case 0x65
            $str = ' (NUMPAD5)'
       Case 0x66
            $str = ' (NUMPAD6)'
       Case 0x67
            $str = ' (NUMPAD7)'
       Case 0x68
            $str = ' (NUMPAD8)'
       Case 0x69
            $str = ' (NUMPAD9)'
       Case 0x6A
            $str = ' (MULTIPLY)'
       Case 0x6B
            $str = ' (ADD)'
       Case 0x6C
            $str = ' (SEPARATOR)'
       Case 0x6D
            $str = ' (SUBTRACT)'
       Case 0x6E
            $str = ' (DECIMAL)'
       Case 0x6F
            $str = ' (DIVIDE)'
       Case 0x70
            $str = ' (F1)'
       Case 0x71
            $str = ' (F2)'
       Case 0x72
            $str = ' (F3)'
       Case 0x73
            $str = ' (F4)'
       Case 0x74
            $str = ' (F5)'
       Case 0x75
            $str = ' (F6)'
       Case 0x76
            $str = ' (F7)'
       Case 0x77
            $str = ' (F8)'
       Case 0x78
            $str = ' (F9)'
       Case 0x79
            $str = ' (F10)'
       Case 0x7A
            $str = ' (F11)'
       Case 0x7B
            $str = ' (F12)'
       Case 0x7C
            $str = ' (F13)'
       Case 0x7D
            $str = ' (F14)'
       Case 0x7E
            $str = ' (F15)'
       Case 0x7F
            $str = ' (F16)'
       Case 0x80
            $str = ' (F17)'
       Case 0x81
            $str = ' (F18)'
       Case 0x82
            $str = ' (F19)'
       Case 0x83
            $str = ' (F20)'
       Case 0x84
            $str = ' (F21)'
       Case 0x85
            $str = ' (F22)'
       Case 0x86
            $str = ' (F23)'
       Case 0x87
            $str = ' (F24)'
; 0x88 to 0x8F are unassigned
       Case 0x90
            $str = ' (NUMLOCK)'
       Case 0x91
            $str = ' (SCRLOCK)'
; 0x92 to 0x96 are OEM-specific
; 0x97 to 0x9F are unassigned
       Case 0xA0
            $str = ' (LSHIFT)'
       Case 0xA1
            $str = ' (RSHIFT)'
       Case 0xA2
            $str = ' (LCTRL)'
       Case 0xA3
            $str = ' (RCTRL)'
       Case 0xA4
            $str = ' (LALT)'
       Case 0xA5
            $str = ' (RALT)'
       Case 0xA6
            $str = ' (BROWSER_BACK)'
       Case 0xA7
            $str = ' (BROWSER_FOWARD)'
       Case 0xA8
            $str = ' (BROWSER_REFRESH)'
       Case 0xA9
            $str = ' (BROWSER_STOP)'
       Case 0xAA
            $str = ' (BROWSER_SEARCH)'
       Case 0xAB
            $str = ' (BROWSER_FAVORITES)'
       Case 0xAC
            $str = ' (BROWSER_HOME)'
       Case 0xAD
            $str = ' (VOLUME_MUTE)'
       Case 0xAE
            $str = ' (VOLUME_DOWN)'
       Case 0xAF
            $str = ' (VOLUME_UP)'
       Case 0xB0
            $str = ' (MEDIA_NEXT_TRACK)'
       Case 0xB1
            $str = ' (MEDIA_PREV_TRACK)'
       Case 0xB2
            $str = ' (MEDIA_STOP)'
       Case 0xB3
            $str = ' (MEDIA_PLAY_PAUSE)'
       Case 0xB4
            $str = ' (LAUNCH_MAIL)'
       Case 0xB5
            $str = ' (LAUNCH_MEDIA_SELECT)'
       Case 0xB6
            $str = ' (LAUNCH_APP_1)'
       Case 0xB7
            $str = ' (LAUNCH_APP_2)'
; 0xB8 to 0xB9 are reserved
       Case 0xBA
            $str = ' (OEM_1)'
       Case 0xBB
            $str = ' (OEM_PLUS)'
       Case 0xBC
            $str = ' (OEM_COMMA)'
       Case 0xBD
            $str = ' (OEM_MINUS)'
       Case 0xBE
            $str = ' (OEM_PERIOD)'
       Case 0xBF
            $str = ' (OEM_2)'
       Case 0xC0
            $str = ' (OEM_3)'
; 0xC1 to 0xD7 are reserved
; 0xD8 to 0xDA are unassigned
       Case 0xDB
            $str = ' (OEM_4)'
       Case 0xDC
            $str = ' (OEM_5)'
       Case 0xDD
            $str = ' (OEM_6)'
       Case 0xDE
            $str = ' (OEM_7)'
       Case 0xDF
            $str = ' (OEM_8)'
; 0xE0 is reserved
; 0xE1 is OEM-specific
       Case 0xE2
            $str = ' (OEM_102)'
; 0xE3 to 0xE4 are OEM-specific
       Case 0xE5
            $str = ' (PROCESSKEY)'
; 0xE6 is OEM-specific
       Case 0xE7
            $str = ' (PACKET)'
; 0xE8 is unassigned
; 0xE9 to 0xF5 are OEM-specific
       Case 0xF6
            $str = ' (ATTN)'
       Case 0xF7
            $str = ' (CRSEL)'
       Case 0xF8
            $str = ' (EXSEL)'
       Case 0xF9
            $str = ' (EREOF)'
       Case 0xFA
            $str = ' (PLAY)'
       Case 0xFB
            $str = ' (ZOOM)'
       Case 0xFC
            $str = ' (NONAME)'
       Case 0xFD
            $str = ' (PA1)'
       Case 0xFE
            $str = ' (OEM_CLEAR)'
  EndSwitch
     Return $str
EndFunc