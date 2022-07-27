#include "include-initialize.au3"

Func Main($switch = null)
   Local Static $state=null
  Switch $switch
    Case Null
      if $state=null then
         $state=false
         While 1
           If $state then
              If Demo() then ContinueLoop
              UpdateText()
              sleep(10)
           Else
              sleep(250)
           EndIf
         WEnd
      endif
    Case Else
         $state = $switch
         Return $state
  EndSwitch
EndFunc

Func RegisterWindowMessagesToCentralHandler($arrMsg)
 for $msg in $arrMsg
     GUIRegisterMsg($msg, OnMessage)
 next
EndFunc

Func InitializeEventListener()
    Global $g_eventListener[32]
    Global $g_eventListenerArgs[32]
    Global $g_eventListenerStatus[32]
    Global $g_eventListenerFunctions[32]
    Global $g_eventListenerMaxIndex = 31
    Global $g_eventListenerQueued = 0
    For $i=0 to $g_eventListenerMaxIndex
        $g_eventListener[$i] = GUICtrlCreateDummy()
        GUICtrlSetOnEvent($g_eventListener[$i], EventCallbackHandler)
    Next
EndFunc

Func InitializeGlobalBuffer($firstUse=false)
    OnMessage(Null, $WM_NULL, Null, Null)                           ; reset timer in the function
    if not $firstuse then InitializeDummyBuffer($gid_on_wm_input)   ; clear dummy buffer if this is not first-time use
    Global $g_rawinput_maxindex = 63
    Global $gid_on_wm_input[$g_rawinput_maxindex+1]
;    Global $g_rawinput_misc[$g_rawinput_maxindex+1][3]
;    Global $g_rawinput_index[$g_rawinput_maxindex+1]
    Global $g_rawinput_buffer[$g_rawinput_maxindex+1][5]
    Global $g_device_list = []
    Global $g_rawinput_queued = 0
    GUISwitch($g_hForm)
    InitializeDummyBuffer($gid_on_wm_input,true)
EndFunc

Func InitializeDummyBuffer(ByRef $array, $flag=false, $func=Callback_WM_INPUT)
  Local $i
  If $flag Then
    For $i=0 to UBound($array)-1
        $array[$i] = GUICtrlCreateDummy()
        GUICtrlSetOnEvent($array[$i], $func)
    Next
  Else
    For $item in $array
        GUICtrlSetOnEvent($item, "")
        GUICtrlDelete($item)
    Next
  EndIf
EndFunc

Func OSMessageMetadata($timestampOverride=null)
; Take the Windows-provided timestamp with a grain of salt, as it only has 10-16ms resolution (you just get deltas of 16, 0, 0... etc). 
; Run your own QueryPerformanceCounter or equivalents in a consistent, lightweight thread if you need accurate timestamping.
     local $msgpos = DllCall($user32dll, 'dword', 'GetMessagePos')
     local $ostime = DllCall($user32dll, 'long', 'GetMessageTime')
     local $msinfo = DllCall($user32dll, 'lparam', 'GetMessageExtraInfo')
     local $array=[ $msgpos[0], $ostime[0], $msinfo[0] ]
     if $timestampOverride then $array[1] = $timestampOverride
     return $array
EndFunc

Func OnMessage($hWnd, $uMsg, $wParam, $lParam)
     local static $epoch=TimerInit(), $buffer_index = 0, $isRecording=false
     local $timestamp = TimerDiff($epoch)
     Switch $uMsg
       Case $WM_INPUT
            If $isRecording Then Return ForwardTimestampedRawinput( $hWnd , $uMsg , $wParam , $lParam , OSMessageMetadata( Demo(false) ? $timestamp : null ) )
;            If $isRecording Then Return Debug_Run_Rawinput_Processor_Immediately( $lParam , OSMessageMetadata( Demo(false) ? $timestamp : null ) )
       Case $WM_INPUT_DEVICE_CHANGE
            Return ForwardTimestampedMsg(Process_Device_Change, $hWnd, $uMsg, $wParam, $lParam, OSMessageMetadata())
       Case $WM_NULL
            $epoch = ( $lParam ? $lParam : TimerInit() )
       Case $WM_NOTIFY
            $isRecording = Main($lParam)
       Case $WM_SYSCOMMAND
            If $isRecording then return ($wParam=0xF060 ? $GUI_RUNDEFMSG : 0) ; always return 0 except for the close window message
       Case $WM_MOVING, $WM_SIZE, $WM_ENTERMENULOOP
            If $isRecording Then CmdSuspend($g_hForm, true)
       Case $WM_SETCURSOR
            Return True
     EndSwitch
EndFunc


     ; hWnd: A handle to the window procedure that received the message.

     ; uMsg: The message. See WindowsConstants.au3 for list. Some relevant examples:
     ; 0x00fe == WM_INPUT_DEVICE_CHANGE
     ; 0x00ff == WM_INPUT
     ; 0x0200 == WM_MOUSEMOVE
     ; 0x0201 == WM_LBUTTONDOWN
     ; 0x0202 == WM_LBUTTONUP
     ; 0x0203 == WM_LBUTTONDBLCLK

     ; -----
     ; For WM_INPUT_DEVICE_CHANGE messages, wParam and lParam are
     ; -----

     ; lParam: The HANDLE to the raw input device.

     ; wParam: This parameter can be one of the following values.
     ; 1 == GIDC_ARRIVAL: A new device has been added to the system. You can call GetRawInputDeviceInfo to get more information regarding the device.
     ; 2 == GIDC_REMOVAL: A device has been removed from the system.

     ; -----
     ; For WM_INPUT messages, wParam and lParam are
     ; -----

     ; lParam: A HRAWINPUT handle to the RAWINPUT structure that contains the raw input from the device. To get the raw data, use this handle in the call to GetRawInputData.

     ; wParam: The input code. Use GET_RAWINPUT_CODE_WPARAM macro to get the value. Can be one of the following values:
     ; 0 == RIM_INPUT received in foreground and need cleanup using DefWindowProc
     ; 1 == RIM_INPUTSINK received in background

     ; -----
     ; For for cursor messages like WM_MOUSEMOVE, WM_LBUTTONDOWN etc, wParam and lParam are
     ; -----

     ; lParam: cursor coordinates.
     ; The low-order word specifies the x-coordinate of the cursor. The coordinate is relative to the upper-left corner of the client area. 
     ; The high-order word specifies the y-coordinate of the cursor. The coordinate is relative to the upper-left corner of the client area.

     ; wParam: The low-order word indicates whether various virtual keys are down. It can be one or more of the following values.
     ; 0x0001 == MK_LBUTTON The left mouse button is down.
     ; 0x0002 == MK_RBUTTON The right mouse button is down.
     ; 0x0004 == MK_SHIFT The SHIFT key is down.
     ; 0x0008 == MK_CONTROL The CTRL key is down.
     ; 0x0010 == MK_MBUTTON the The middle mouse button is down.
     ; 0x0020 == MK_XBUTTON1 The first X button is down.
     ; 0x0040 == MK_XBUTTON2 The second X button is down.
     ; case of X buttons: The high-order word indicates which X button triggered the event. It can be one of the following values.
     ; 0x0001 == XBUTTON1 Triggered by the first X button.
     ; 0x0002 == XBUTTON2 Triggered by the second X button.
     ; case of scrollwheel: The high-order word indicates the distance the wheel is rotated, expressed in multiples or divisions of WHEEL_DELTA, which is 120. A positive value indicates that the wheel was rotated forward, away from the user; a negative value indicates that the wheel was rotated backward, toward the user.

Func ForwardTimestampedMsg($func, $hWnd, $uMsg, $wParam, $lParam, ByRef $misc)
     local $args = DllStructCreate("struct;hwnd hWnd;uint uMsg;wparam wParam;lparam lParam;double time;lparam info;dword pos;endstruct")
     DllStructSetData($args, "hWnd", $hWnd)
     DllStructSetData($args, "uMsg", $uMsg)
     DllStructSetData($args, "wParam", $wParam)
     DllStructSetData($args, "lParam", $lParam)
     DllStructSetData($args, "pos", $misc[0])
     DllStructSetData($args, "time", $misc[1])
     DllStructSetData($args, "info", $misc[2])
     $g_eventListenerQueued = $g_eventListenerQueued + QueueEvent($func, $args, $misc[1])
     Return 0
EndFunc

Func ForwardTimestampedRawinput($hWnd, $uMsg, $wParam, $lParam, ByRef $misc)
     $g_rawinput_queued += WriteToRawinputBuffer($lParam, $misc, $misc[1])
     Return 0
EndFunc

Func EventCallbackHandler()
     local $index = GUICtrlRead(@GUI_CTRLID)
     local $func = $g_eventListenerFunctions[$index]
     local $args = $g_eventListenerArgs[$index]
;     local $arr[2] = ["CallArgArray", $args]
     $g_eventListenerStatus[$index] = false
     $g_eventListenerQueued -= 1
;     Call($func,$arr)
     $func($args)
EndFunc

Func Callback_WM_INPUT()
     local $index = GUICtrlRead(@GUI_CTRLID)
     local $data =   $g_rawinput_buffer[$index][1]
     local $misc = [ $g_rawinput_buffer[$index][2] , $g_rawinput_buffer[$index][3] , $g_rawinput_buffer[$index][4] ]
     $g_rawinput_buffer[$index][0] = false
     $g_rawinput_queued -= 1
     Process_Rawinput_Data($data, $misc)
EndFunc

Func QueueEvent($func, $args, $time)
     Local Const $MAX = $GlOBAL_MAXIMUM_BUFFER_SIZE
     Local Static $buffer_index = 0
     If $g_eventListenerQueued < $MAX then
                  $buffer_index = _Min($buffer_index, $g_eventListenerMaxIndex)
                  local $i, $j = $buffer_index, $k = $g_eventListenerMaxIndex
                  For $i = 0 To $k
                      if  $g_eventListenerStatus[$j] then
                          $j = Mod($j+1, $k+1)
                      else
                          $g_eventListenerStatus[$j] = true
                          $g_eventListenerArgs[$j] = $args
                          $g_eventListenerFunctions[$j] = $func
                          GUICtrlSendToDummy($g_eventListener[$j], $j)
                          $buffer_index = Mod($j+1, $k+1)
                          Return 1
                      endif
                  Next
                  Local $a, $b, $c, $d
                  $a = _ArrayAdd($g_eventListenerStatus, true)
                  $b = _ArrayAdd($g_eventListenerArgs, $args)
                  $c = _ArrayAdd($g_eventListenerFunctions, $func)
                  $d = _ArrayAdd($g_eventListener, GUICtrlCreateDummy())
                  GUICtrlSetOnEvent($g_eventListener[$d], "EventCallbackHandler")
                  GUICtrlSendToDummy($g_eventListener[$d], $b)
                  $g_eventListenerMaxIndex += 1
                  Return ( ( $a = $b ) ? ( 1 ) : ( exit ) )
     Else
                  FileWrite($gReportFileMkb, "DROPPED EVENT " & $func & " AT T=" & $time & @CRLF)
                  Return 0
     EndIf
EndFunc

Func WriteToRawinputBuffer($lParam, ByRef $misc, $time)
     Local Static $tHeader = 'struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct;'
     Local Static $tMouse = $tHeader & 'ushort Flags;ushort Alignment;ushort ButtonFlags;short ButtonData;ulong RawButtons;long LastX;long LastY;ulong ExtraInformation;' , _
                  $tKeybd = $tHeader & 'ushort MakeCode;ushort Flags;ushort Reserved;ushort VKey;uint Message;ulong ExtraInformation;' , _
                  $tHidev = $tHeader & 'dword SizeHid;dword Count;'
     Local Static $sizeHeader = DllStructGetSize(DllStructCreate($tHeader)), _
                  $sizeMouse  = DllStructGetSize(DllStructCreate($tMouse)), _
                  $sizeKeybd  = DllStructGetSize(DllStructCreate($tKeybd)), _
                  $sizeHIDev  = DllStructGetSize(DllStructCreate($tHidev))
     Local Static $buffer_index = 0
     Local $a = DllCall($user32dll, _
                            'uint', 'GetRawInputData', _
                          'handle', $lParam, _
                            'uint', 0x10000005, _
                         'struct*', DllStructCreate($tHeader), _
                           'uint*', $sizeHeader, _
                            'uint', $sizeHeader)

     If $a[0] Then
        Switch DllStructGetData($a[3],"Type")
          Case 0 ; mouse
               Local $tag = $tMouse
          Case 1 ; keyboard
               Local $tag = $tKeybd
          Case 2 ; hid
               Local $tag = $tHidev & 'byte RawData[' & (DllStructGetData($a[3],"Size")-$sizeHidev) & '];'
          Case Else
               FileWrite($gReportFileMkb, "INVALID TYPE AT T=" & $time & @CRLF)
               Return 0
        EndSwitch
        ; if this is changed to getrawinputbuffer then it would simply loop through them and increment a counter for number of reports added, then return that counter. 
        ; Race condition check is done each time a report is added
        $a = DllCall($user32dll, _
                         'uint', 'GetRawInputData', _
                       'handle', $lParam, _
                         'uint', 0x10000003, _
                      'struct*', DllStructCreate($tag), _
                        'uint*', DllStructGetData($a[3],"Size"), _
                         'uint', $sizeHeader)
        if $a[0] then
            $buffer_index = _Min($buffer_index, $g_rawinput_maxindex)
            local $i, $j = $buffer_index, $k = $g_rawinput_maxindex
            if $g_rawinput_queued<$GLOBAL_MAXIMUM_BUFFER_SIZE then          ; if the number of queued events isn't full, scan buffer to check that it's not already occupied
               For $i = 0 To $k                                             ; loop through the buffer once, submit and return if found an empty slot
                   if  $g_rawinput_buffer[$j][0] then
                       $j = Mod($j+1, $k+1)
                   else
                       $g_rawinput_buffer[$j][0] = true
                       $g_rawinput_buffer[$j][1] = $a[3]
                       $g_rawinput_buffer[$j][2] = $misc[0] ; position
                       $g_rawinput_buffer[$j][3] = $misc[1] ; timestamp
                       $g_rawinput_buffer[$j][4] = $misc[2] ; extrainfo
                       GUICtrlSendToDummy($gid_on_wm_input[$j], $j)
                       $buffer_index = Mod($j+1, $k+1)
                       Return 1                                             ; returns number of reports advanced to the buffer, which is 1
                   endif
               Next
               Return ExpandDummyBuffer($a[3], $misc)                       ; if no empty slot is found after one loop, expand the buffer by 1, and report that 1 message has been added
            else                                                            ; if buffer cannot be expanded further, simply look for any stale report to overwrite, and report that one has been overwritten
               For $i = 0 To $k
                   if  $g_rawinput_buffer[$j][3]>=$time then                ; if report is fresher than current, don't overwrite
                       $j = Mod($j+1, $k+1)
                   else
                       $g_rawinput_buffer[$j][0] = true
                       $g_rawinput_buffer[$j][1] = $a[3]
                       $g_rawinput_buffer[$j][2] = $misc[0] ; position
                       $g_rawinput_buffer[$j][3] = $misc[1] ; timestamp
                       $g_rawinput_buffer[$j][4] = $misc[2] ; extrainfo
                       GUICtrlSendToDummy($gid_on_wm_input[$j], $j)
                       $buffer_index = Mod($j+1, $k+1)
                       Return 1                                             ; even though it's overwritten, the previously written but stale event is still already queued, so eventually it will clear its own count, thus us adding one new event will invariably increase the number of events queued to the Autoit engine
                   endif
               Next
               FileWrite($gReportFileMkb, "DROPPED INPUT AT T=" & $time & @CRLF)
               Return 0
            endif
        else
            FileWrite($gReportFileMkb, "NO CONTENT AT T=" & $time & @CRLF)
            Return 0
        endif
     Else
        FileWrite($gReportFileMkb, "NO HEADER AT T=" & $time & @CRLF)
        Return 0
     EndIf
EndFunc

Func ExpandDummyBuffer($tRIM, ByRef $misc)
     Local $oldmaxindex = $g_rawinput_maxindex
     ReDim $g_rawinput_buffer[$oldmaxindex+2][5]
     $g_rawinput_buffer[$oldmaxindex+1][0] = true
     $g_rawinput_maxindex += 1
     if $oldmaxindex+1 = $g_rawinput_maxindex then
        GUISwitch($g_hForm)
        Local $dummyindex = _ArrayAdd($gid_on_wm_input, GUICtrlCreateDummy())
        GUICtrlSetOnEvent( $gid_on_wm_input[$dummyindex], "Callback_WM_INPUT")
        $g_rawinput_buffer[$oldmaxindex+1][1] = $tRIM
        $g_rawinput_buffer[$oldmaxindex+1][2] = $misc[0]
        $g_rawinput_buffer[$oldmaxindex+1][3] = $misc[1]
        $g_rawinput_buffer[$oldmaxindex+1][4] = $misc[2]
        GUICtrlSendToDummy($gid_on_wm_input[$dummyindex], $oldmaxindex+1)
        return 1
     else
        MsgBox(0,"Error: race condition has occurred" & @error,"Message added at index " & $oldmaxindex+1 & ", but new max index is " & $g_rawinput_maxindex)
        Exit
     endif
EndFunc

Func Debug_Run_Rawinput_Processor_Immediately($lParam, ByRef $misc)
     Local $tRIM = DllStructCreate($tagRAWINPUTHEADER)
     If _WinAPI_GetRawInputData($lParam, $tRIM, DllStructGetSize($tRIM), $RID_HEADER) then
        Switch DllStructGetData($tRIM,"Type")
          Case 0 ; mouse
               $tRIM = DllStructCreate($tagRAWINPUTMOUSE)
          Case 1 ; keyboard
               $tRIM = DllStructCreate($tagRAWINPUTKEYBOARD)
          Case 2 ; hid
               $tRIM = DllStructCreate($tagRAWINPUTHID)
        EndSwitch
	if _WinAPI_GetRawInputData($lParam, $tRIM, DllStructGetSize($tRIM), $RID_INPUT) then
            Process_Rawinput_Data($tRIM, $misc)
	else
	    FileWrite($gReportFileMkb, "NODATA AT T=" & $misc[1] & @CRLF)
	endif
     EndIf
     Return 0
EndFunc

Func RawinputStateController($enable=null)
     ; UsagePage 0x01 = generic desktop controls; Usage 0x01 = pointer
     ; UsagePage 0x01 = generic desktop controls; Usage 0x02 = mouse
     ; UsagePage 0x01 = generic desktop controls; Usage 0x03 = reserved
     ; UsagePage 0x01 = generic desktop controls; Usage 0x04 = joystick
     ; UsagePage 0x01 = generic desktop controls; Usage 0x05 = gamepad
     ; UsagePage 0x01 = generic desktop controls; Usage 0x06 = keyboard
     Local Const $defaultregistry = [[]]
     Local Static $registeredusages=$defaultregistry
     Local $flags, $handle
     Switch $enable
       Case True
            $flags = $RIDEV_INPUTSINK+$RIDEV_DEVNOTIFY
            $handle = $g_hForm
            InitializeGlobalBuffer()
            $registeredusages = GetConnectedRawinputDevicesUsages(GetDeviceSubscriptionMode())
            For $i=0 to UBound($registeredusages,1)-1
                RegisterRawInputDevice($registeredusages[$i][0], $registeredusages[$i][1], $flags, $handle)
            Next
       Case False
            $flags = $RIDEV_REMOVE
            $handle = ""
            For $i=0 to UBound($registeredusages,1)-1
                RegisterRawInputDevice($registeredusages[$i][0], $registeredusages[$i][1], $flags, $handle)
            Next
            $registeredusages=$defaultregistry
       Case Else
            Return $registeredusages
     EndSwitch
EndFunc



; https://www.freebsddiary.org/APC/usb_hid_usages.php
; Usage ID  Usage Name             hidusage.h constant
;     0x00  Undefined
;     0x01  Pointer                HID_USAGE_GENERIC_POINTER
;     0x02  Mouse                  HID_USAGE_GENERIC_MOUSE
;     0x03  Reserved
;     0x04  Joystick               HID_USAGE_GENERIC_JOYSTICK
;     0x05  Game Pad               HID_USAGE_GENERIC_GAMEPAD
;     0x06  Keyboard               HID_USAGE_GENERIC_KEYBOARD
;     0x07  Keypad                 HID_USAGE_GENERIC_KEYPAD
;     0x08  Multi-axis Controller  HID_USAGE_GENERIC_MULTI_AXIS_CONTROLLER
;
; NOTE: each process gets only one subscription to the same device class. 
; Registering multiple windows to the same device class just makes the OS send their messages only to latest one that signed up



Func RegisterRawInputDevice($usagepage, $usage, $flags, $htarget)
     Local $tRID = DllStructCreate($tagRAWINPUTDEVICE)
     DllStructSetData($tRID, 'UsagePage', $usagepage)
     DllStructSetData($tRID, 'Usage', $usage)
     DllStructSetData($tRID, 'Flags', $flags)
     DllStructSetData($tRID, 'hTarget', $htarget)
     _WinAPI_RegisterRawInputDevices($tRID)
EndFunc

Func Process_Device_Change($msg)
     GUIRegisterMsg( $WM_INPUT, '' ) ; halt inflow of rawinput messages without changing system state
;     Local $hWnd   = DllStructGetData($msg,"hWnd")
;     Local $uMsg   = DllStructGetData($msg,"uMsg")
     Local $wParam = DllStructGetData($msg,"wParam")
     Local $lParam = DllStructGetData($msg,"lParam")
     Local $pos    = DllStructGetData($msg,"pos")
     Local $time   = DllStructGetData($msg,"time")
     Local $info   = DllStructGetData($msg,"info")

     Local $posX = BitAnd($pos, 0xFFFF)
     Local $posY = BitShift($pos, 16)
     Local $str_info = "0x" & Hex($info, 16)


     Local $add = ($wParam-1) ? (false) : (true)
     Local $filelog, $logstring = ( ($add) ? ("+") : ("-") ) & Hex($lParam) & " (t=" & $time & ", x=" & $posX & ", y=" & $posY & ")" & @CRLF
     UpdateList($logstring)
     If $add Then 
        FileWrite($gReportFileMkb, "arrve=,0x" & Hex($lParam,16) & ", =,, =,, =,, =,, =,, ostime=," & $time & ", oscoord=,(" & $posX & " " & $posY & "), osextra=" & $str_info & @CRLF)
        FileWrite($gReportFileLst, @CRLF & "==============" & @CRLF & " GIDC_ARRIVAL " & @CRLF & "==============" & @CRLF & GetConnectedRawinputDevicesInfoString($lParam) & @CRLF)
     Else
        FileWrite($gReportFileMkb, "remov=,0x" & Hex($lParam,16) & ", =,, =,, =,, =,, =,, ostime=," & $time & ", oscoord=,(" & $posX & " " & $posY & "), osextra=" & $str_info & @CRLF)
        FileWrite($gReportFileLst, @CRLF & "==============" & @CRLF & " GIDC_REMOVAL " & @CRLF & "==============" & @CRLF & "Handle: 0x" & Hex($lParam,16) & @CRLF)
     EndIf
     GUIRegisterMsg( $WM_INPUT, OnMessage ) ; restore inflow of rawinput messages
EndFunc


Func Process_Rawinput_Data($tRIM, ByRef $misc)
  Local Static $lastMouTime, $lastKeyTime, $lastHidTime  ; TODO: keep track of per-device delta time rather than lumping by type
  Local $cacheMouTime=$lastMouTime
  Local $cacheKeyTime=$lastKeyTime
  Local $cacheHidTime=$lastHidTime
  Local $posX = BitAnd($misc[0], 0xFFFF) ; from GetMessagePos(), lo-short
  Local $posY = BitShift($misc[0], 16)   ; from GetMessagePos(), hi-short
  Local $time = $misc[1]                 ; from GetMessageTime()
  Local $info = "0x"&Hex($misc[2], 16)   ; from GetMessageExtraInfo()

  ; RAWINPUTHEADER
  Local $dwType  = DllStructGetData($tRIM, 'Type') ; RIM_TYPEMOUSE 0, RIM_TYPEKEYBOARD 1, RIM_TYPEHID 2
  Local $dwSize  = DllStructGetData($tRIM, 'Size') ; The size, in bytes, of the entire input packet of data. This includes RAWINPUT plus possible extra input reports in the RAWHID variable length array.
  Local $hDevice = DllStructGetData($tRIM, 'hDevice')
  Local $wParam  = DllStructGetData($tRIM, 'wParam')

  Switch $dwType
    Case 0 ; RAWMOUSE

         Local $deltaTime = $cacheMouTime > $time ? $cacheMouTime : $time - $cacheMouTime
         $lastMouTime = $time

         Local $usFlags = DllStructGetData($tRIM, 'Flags')                ; Specifies a bitwise OR of one or more of the mouse indicator flags.
         Local $usButtonFlags = DllStructGetData($tRIM, 'ButtonFlags')    ; Specifies the transition state of the mouse buttons.
         Local $usButtonData = DllStructGetData($tRIM, 'ButtonData')      ; Specifies mouse wheel data, if MOUSE_WHEEL is set in ButtonFlags.
         Local $ulRawButtons = DllStructGetData($tRIM, 'RawButtons')      ; Specifies the raw state of the mouse buttons. The Win32 subsystem does not use this member.
         Local $lLastX = DllStructGetData($tRIM, 'LastX')                 ; Specifies the signed relative or absolute motion in the x direction.
         Local $lLastY = DllStructGetData($tRIM, 'LastY')                 ; Specifies the signed relative or absolute motion in the y direction.
         Local $ulExtraInfo = DllStructGetData($tRIM, 'ExtraInformation') ; Specifies device-specific information.

         ; put whatever extra function you want to do here. This is where you would filter inputs by device and process them separately
         if Demo(false) then
            local static $alttabbed=false
            if $wParam then                                                                           ; as soon as one in-background report is received, we know we are alt-tabbed
               $alttabbed = true                                                                      ; keep setting it to true, even as you receive them
            else                                                                                      ; window restore check
               if $alttabbed then                                                                     ; if was alttabbed but now are receiving foreground, then we are no longer alttabbed
                  $alttabbed = false                                                                  ; no longer alttabbed
                  CameraLockSetState()                                                                ; re-lock cursor accordingly
               endif
               if $lLastX or $lLastY then UpdateMovementCmd($lLastX, $lLastY, $posX, $posY, $hDevice) ; It is ok to move first before updating buttons, since you can't distinguish between the order witin the same report.
               if $usButtonFlags then UpdateButtonState($usButtonFlags, $usButtonData, $hDevice)
            endif
            FileWrite($gReportFileMkb, "mouse=," & $hDevice & ", bflg=,0x" & Hex($usButtonFlags,4) & ", bdta=,0x" & Hex($usButtonData,2) & ", dx=," & $lLastX & ", dy=," & $lLastY & ", dt=," & $deltaTime & ", time=," & $time & ", oscoord=,(" & $posX & " " & $posY & ")" & @CRLF)
         else
            local $newstring = "== RAWINPUTHEADER ==" & @CRLF & _
                               "Device Type: " & _deviceType($dwType) & @CRLF & _
                               "Report Size: " & $dwSize & " bytes" & @CRLF & _
                               "Device Handle: " & $hDevice & @CRLF & _
                               "Received in Background: " & ($wParam?"TRUE":"FALSE") & @CRLF & _
                               @CRLF & _
                               "== RAWMOUSE ==" & @CRLF & _
                               "Delta:       " & $lLastX & ", " & $lLastY & @CRLF & _
                               "Flags:       " & "0x" & Hex($usFlags,4) & _usFlagsMouse($usFlags) & @CRLF & _
                               "Button Flag: " & "0x" & Hex($usButtonFlags,4) & _usButtonFlags($usButtonFlags) & @CRLF & _
                               "Button Data: " & ($usButtonData>0?"+"&$usButtonData:$usButtonData) & @CRLF & _
                               "Raw Buttons: " & "0x" & Hex($ulRawButtons,16) & @CRLF & _
                               "Extra Info:  " & "0x" & Hex($ulExtraInfo,16)  & @CRLF & _
                               @CRLF & _
                               "== MSGINFO ==" & @CRLF & _
                               "OS Timestamp: " & $time & " ms" & @CRLF & _
                               "OS EvntCoord: " & $posX & ", " & $posY & @CRLF & _
                               "OS ExtraInfo: " & $info ;& ", " & $deltaTime
            UpdateText($newstring) ; this only writes to static variable in the function without triggering update
            FileWrite($gReportFileMkb, "mouse=," & $hDevice & ", bflg=,0x" & Hex($usButtonFlags,4) & ", bdta=,0x" & Hex($usButtonData,2) & ", dx=," & $lLastX & ", dy=," & $lLastY & ", ostime=," & $time & ", oscoord=,(" & $posX & " " & $posY & ")" & @CRLF)
         endif


    Case 1 ; RAWKEYBOARD

         Local $deltaTime = $cacheKeyTime > $time ? $cacheKeyTime : $time - $cacheKeyTime
         $lastKeyTime = $time

         Local $usMakeCode  = DllStructGetData($tRIM, 'MakeCode')         ; Specifies the scan code (from Scan Code Set 1) associated with a key press. 
         Local $usFlags     = DllStructGetData($tRIM, 'Flags')            ; Flags for scan code information. It can be one or more of the following: 0, 1, 2, 4 for keydown, keyup, E0 prefix, E1 prefix
         Local $usReserved  = DllStructGetData($tRIM, 'Reserved')         ; Reserved; must be zero.
         Local $usVkey      = DllStructGetData($tRIM, 'Vkey')             ; The corresponding legacy virtual-key code.
         Local $uiMessage   = DllStructGetData($tRIM, 'Message')          ; The corresponding legacy keyboard window message, for example WM_KEYDOWN, WM_SYSKEYDOWN, and so forth.
         Local $ulExtraInfo = DllStructGetData($tRIM, 'ExtraInformation') ; The device-specific additional information for the event.

         if Demo(false) then
            if not $wParam then
               if $usVkey = 0x1b then GUICmdDemoButton()
            endif
            FileWrite($gReportFileMkb, "keybd=," & $hDevice & ", wmsg=,0x" & Hex($uiMessage,4) & ", vkey=,0x" & Hex($usVkey,2) & ", make=," & Hex($usMakeCode,2) & ", flag=," & $usFlags & ", dt=," & $deltaTime & ", time=," & $time & @CRLF)
         else
            local $newstring = "== RAWINPUTHEADER ==" & @CRLF & _
                               "Device Type: " & _deviceType($dwType) & @CRLF & _
                               "Report Size: " & $dwSize & " bytes" & @CRLF & _
                               "Device Handle: " & $hDevice & @CRLF & _
                               "Received in Background: " & ($wParam?"TRUE":"FALSE") & @CRLF & _
                               @CRLF & _
                               "== RAWKEYBOARD ==" & @CRLF & _
                               "Make Code:   " & "0x" & Hex($usMakeCode,4) & @CRLF & _
                               "Flags:       " & "0x" & Hex($usFlags,4) & _usFlagsKeyboard($usFlags) & @CRLF & _
                               "Reserved:    " & "0x" & Hex($usReserved,4) & @CRLF & _
                               "Virtual Key: " & "0x" & Hex($usVkey,4) & _usVkey($usVkey) & @CRLF & _
                               "Win Message: " & "0x" & Hex($uiMessage,8) & _uiMessage($uiMessage) & @CRLF & _
                               "Extra Info:  " & "0x" & Hex($ulExtraInfo,16) & @CRLF & _
                               @CRLF & _
                               "== MSGINFO ==" & @CRLF & _
                               "OS Timestamp: " & $time & " ms" & @CRLF & _
                               "OS EvntCoord: " & $posX & ", " & $posY & @CRLF & _
                               "OS ExtraInfo: " & $info ;& ", " & $deltaTime
            UpdateText($newstring) ; this only writes to static variable in the function without triggering update
            FileWrite($gReportFileMkb, "keybd=," & $hDevice & ", wmsg=,0x" & Hex($uiMessage,4) & ", vkey=,0x" & Hex($usVkey,2) & ", make=," & Hex($usMakeCode,2) & ", flag=," & $usFlags & ", ostime=," & $time & ", oscoord=,(" & $posX & " " & $posY & ")" & @CRLF)
         endif

    Case 2 ; RAWHID
         Local $deltaTime = $cacheHidTime > $time ? $cacheHidTime : $time - $cacheHidTime
         $lastHidTime = $time

         Local $dwSizeHid = DllStructGetData($tRIM, 'SizeHid')
         Local $dwCount   = DllStructGetData($tRIM, 'Count')
         Local $bRawData  = DllStructGetData($tRIM, 'RawData')
         if Demo(false) then
         else
            local $newstring = "== RAWINPUTHEADER ==" & @CRLF & _
                               "Device Type: " & _deviceType($dwType) & @CRLF & _
                               "Report Size: " & $dwSize & " bytes" & @CRLF & _
                               "Device Handle: " & $hDevice & @CRLF & _
                               "Received in Background: " & ($wParam?"TRUE":"FALSE") & @CRLF & _
                               @CRLF & _
                               "== RAWHID ==" & @CRLF & _
                               "Bytes per Input: " & $dwSizeHid & @CRLF & _
                               "Number of Inputs: " & $dwCount & @CRLF & _
                               "Raw Data: " & $bRawData & @CRLF & _
                               @CRLF & _
                               "== MSGINFO ==" & @CRLF & _
                               "OS Timestamp: " & $time & " ms" & @CRLF & _
                               "OS EvntCoord: " & $posX & ", " & $posY & @CRLF & _
                               "OS ExtraInfo: " & $info ;& ", " & $deltaTime
            UpdateText($newstring) ; this only writes to static variable in the function without triggering update
         endif

         FileWrite($gReportFileMkb, "hidev=," & $hDevice & ", byte=," & $dwSizeHid & ", ninp=," & $dwCount & ", rdta=," & $bRawData & ", =,, ostime=," & $time & ", oscoord=,(" & $posX & " " & $posY & ")" & @CRLF)

  EndSwitch
EndFunc

Func UpdateText($newstring="", $newhandle=null)
  Local Static $currentstring = "", $laststring = "", $handle=null, $update=0
  local $cacheupdate=$update
  if $newhandle then             ; called from initialization, informs static variable of change in edit control handle
     $handle = $newhandle
     return
  endif
  if $newstring then             ; called from input processor, just updates variable then return
     $currentstring = $newstring
     $update += 1
     return
  endif
  if $cacheupdate>0 then           ; called from main, refreshes content of edit control
     $update -= $cacheupdate
     GUICtrlSetData($handle, $currentstring)
;WinSetTitle($g_hForm, "", $g_rawinput_queued & "/" & $g_rawinput_maxindex+1 )
  endif
EndFunc

Func UpdateList($newstring="", $overwrite=null, $newhandle=null)
  Local Static $handle=null
  if $newhandle then $handle = $newhandle
  if $newstring then GUICtrlSetData($handle, $newstring, "append")
  if $overwrite then GUICtrlSetData($handle, $newstring)
EndFunc

Func UpdateMovementCmd($lLastX, $lLastY, $posX, $posY, $handle=null)
     Local Static $singleton_cache = DemoSingletonState() ; TODO: refactor DemoSingletonState to take device handle and return struct address, then change this line to Local instead of Local Static (and pass handle)
     Local $cameramode = DllStructGetData($singleton_cache, "camlock")
     Local $drag_state = DllStructGetData($singleton_cache, "draglock")
     Local $sendX=0, $sendY=0
        if $cameramode then   ; camlock mode true, FPS-like
           $sendX = $lLastX
           $sendY = $lLastY
        else                  ; camlock mode false, RTS-like
          if $drag_state then   
             ; drag pan
             $sendX = -$lLastX
             $sendY = -$lLastY
          else                 
             ; edge pan
             if ($posX+$lLastX<$g_mousetrap_bound[0]) or ($posX+$lLastX>$g_mousetrap_bound[2]-1) then $sendX=$lLastX
             if ($posY+$lLastY<$g_mousetrap_bound[1]) or ($posY+$lLastY>$g_mousetrap_bound[3]-1) then $sendY=$lLastY
          endif
        endif
        MoveMouseDelta($sendX, $sendY, $singleton_cache)
EndFunc

Func UpdateButtonState($usButtonFlags, $usButtonData, $handle=null)
     Local Static $singleton_cache = DemoSingletonState() ; TODO: refactor DemoSingletonState to take device handle and return struct address, then change this line to Local instead of Local Static (and pass handle)
     Local $xhairstate = DllStructGetData($singleton_cache, "color")
     Local $cameramode = DllStructGetData($singleton_cache, "camlock")
     Local $drag_state = DllStructGetData($singleton_cache, "draglock")

        ; crosshair color state. Is latency sensitive
        if BitAND($usButtonFlags,1)  then $xhairstate = BitOR( $xhairstate, 0x000000ff ) ; add blue to state
        if BitAND($usButtonFlags,2)  then $xhairstate = BitAND($xhairstate, 0xffffff00 ) ; subtract blue from state
        if BitAND($usButtonFlags,4)  then $xhairstate = $cameramode ? BitAND($xhairstate, 0x00ff00ff ) : BitOR( $xhairstate, 0xff00ff00 )
        if BitAND($usButtonFlags,16) then $xhairstate = BitOR( $xhairstate, 0x00ff0000 ) ; add red to state
        if BitAND($usButtonFlags,32) then $xhairstate = BitAND($xhairstate, 0xff00ffff ) ; subtract red from state
        if $usButtonFlags then 
           SetCrosshairColor($xhairstate, $singleton_cache) ; only update color if actual commands are sent
           Switch BitAND(0x00ffffff,$xhairstate)
             Case 0x00ffffff
	          DllCall($user32dll, "handle", "SetCursor", "handle", $hWhiteCursor[0])
             Case 0x0000ffff
	          DllCall($user32dll, "handle", "SetCursor", "handle", $hCyanCursor[0])
             Case 0x00ffff00
	          DllCall($user32dll, "handle", "SetCursor", "handle", $hYellowCursor[0])
             Case 0x0000ff00
	          DllCall($user32dll, "handle", "SetCursor", "handle", $hLimeCursor[0])
           EndSwitch
        endif

        ; camera mode toggle check. Not latency-sensitive
        if BitAND($usButtonFlags,1) then DragLockSetState(true, $singleton_cache)
        if BitAND($usButtonFlags,2+16) then DragLockSetState(false, $singleton_cache)
        if BitAND($usButtonFlags,4) then CameraLockSetState(not $cameramode, $singleton_cache)
        if BitAND($usButtonFlags,1024) then ChangeZoomLevel($usButtonData, $singleton_cache)

        ; TODO: these should be per device
        if BitAND(BitAND($usButtonFlags,16),16) then
           $g_middle_drag = MouseGetPos()
           AdlibRegister ( "PanCamera" , 10 )
        endif
        if BitAND($usButtonFlags,1+4+32) then 
           AdlibUnRegister ( "PanCamera" )
        endif
EndFunc

Func CameraLockSetState($lock=null, $ptr=null)
     Local Static $singleton_cache=DemoSingletonState() ; TODO: refactor DemoSingletonState to take device handle and return struct address, then change this line to Local instead of Local Static (and pass handle)
     Local $address = ($ptr=null) ? $singleton_cache : $ptr
     if $lock=null then
        Demo(false, DllStructGetData($address,"camlock"))  ; default case just locks all devices accordingly, although the per-device feature is currently a stub
     else
        DllStructSetData($address, "camlock", $lock)
        Demo(false, $lock)
     endif
     ; TODO: bad idea to call a higher level function like Demo() from a low level one like this
EndFunc

Func DragLockSetState($lock, $ptr)
     DllStructSetData($ptr, "draglock", $lock)
EndFunc

Func MoveMouseDelta($dx, $dy, $ptr)
     DllStructSetData($ptr, "x", DllStructGetData($ptr, "x")+$dx)
     DllStructSetData($ptr, "y", DllStructGetData($ptr, "y")+$dy)
EndFunc

Func SetCrosshairColor($color, $ptr)
     DllStructSetData($ptr, "color", $color)
EndFunc

Func ChangeZoomLevel($step, $ptr)
     Local Const $scale = 2
     Local Const $period = 12*120
     Local $newmodx, $newmody, $newmodz, $newsize, $magnify
     Local $oldmodx = DllStructGetData($ptr,"x")
     Local $oldmody = DllStructGetData($ptr,"y")
     Local $oldmodz = DllStructGetData($ptr,"z")
     Local $oldsize = DllStructGetData($ptr,"gridsize")
     $newmodz = $oldmodz + $step
     $newmodz = $newmodz - $period*round($newmodz/$period)
     $newsize = round( $GLOBAL_INITIAL_GRIDSIZE*exp(log($scale)*$newmodz/$period) )
     $magnify = exp(log($scale)*($step)/$period)
     if     $newmodz-$oldmodz < $step then
        $newmody = round(mod($oldmody+$oldsize/$scale,$oldsize)*$magnify)
        $newmodx = round(mod($oldmodx+$oldsize/$scale,$oldsize)*$magnify)
     elseif $newmodz-$oldmodz > $step then
        $newmody = round(mod($oldmody*$magnify-$newsize/$scale,$newsize))
        $newmodx = round(mod($oldmodx*$magnify-$newsize/$scale,$newsize))
     else ; if not wrapped
        $newmody = round(mod($oldmody,$oldsize)*$magnify)
        $newmodx = round(mod($oldmodx,$oldsize)*$magnify)
     endif
     DllStructSetData( $ptr,        "x", $newmodx ) ; renormalize
     DllStructSetData( $ptr,        "y", $newmody ) ; renormalize
     DllStructSetData( $ptr,        "z", $newmodz )
     DllStructSetData( $ptr, "gridsize", $newsize )
EndFunc

Func InitializeSingletonState()
     Local Static $singleton_demo_state = DllStructCreate("struct;long x;long y;long color;long z;long gridsize;boolean camlock;boolean draglock;endstruct")
     DllStructSetData($singleton_demo_state, "x", 0)
     DllStructSetData($singleton_demo_state, "y", 0)
     DllStructSetData($singleton_demo_state, "z", 0)
     DllStructSetData($singleton_demo_state, "color", $GLOBAL_INITIAL_XHAIR_COLOR)
     DllStructSetData($singleton_demo_state, "gridsize", $GLOBAL_INITIAL_GRIDSIZE)
     DllStructSetData($singleton_demo_state, "camlock", true)
     DllStructSetData($singleton_demo_state, "draglock", false)
     return $singleton_demo_state
EndFunc

Func DemoSingletonState($init=null) ; todo: refactor to take device handle, and return the corresponding handle when queried.
     Local Static $singleton_demo_state = InitializeSingletonState()
     if $init then InitializeSingletonState()
     return $singleton_demo_state ; by default just fetch address to struct
EndFunc

Func DemoStartupProcedure(ByRef $ref_hWnd, ByRef $ref_hHBITMAP, ByRef $ref_hDC, ByRef $ref_hDC_Backbuffer, ByRef $ref_oDC_Obj, ByRef $ref_hGfxCtxt, ByRef $ref_hPen, ByRef $mouse)
    Local $arr[4]
    $arr[0] = ProgramCommand("demo_render_width")
    $arr[1] = ProgramCommand("demo_render_height")
    $arr[0] = $arr[0]>640?round($arr[0]):640
    $arr[1] = $arr[1]>480?round($arr[1]):480
    $arr[2] = round((@DeskTopWidth-$arr[0])/2)
    $arr[3] = round((@DeskTopHeight-$arr[1])/2)
    BackupPointerSpeedAndAccel($mouse)
    DisablePointerSpeedAndAccel()
    DemoSingletonState(true) ; ask it to initialize state
;    $ref_hWnd = GUICreate($i18n_demo_wintitle, @DeskTopWidth,@DeskTopHeight,0,0,$WS_POPUP,34078728)

    $ref_hWnd = GUICreate($i18n_demo_wintitle, $arr[0], $arr[1], $arr[2], $arr[3], $WS_POPUP)
    GUISetBkColor($COLOR_BLACK, $ref_hWnd)
    GUISetIcon($GLOBAL_PROGRAM_ICON_PATH,229)
    FrameCounterSingleton(False, $ref_hWnd)
    AdlibRegister ( "FrameCounterUpdate" , 1000 )

; ------------------ adapted example Autoit Code from https://www.autoitscript.com/autoit3/docs/libfunctions/_WinAPI_BitBlt.htm ------------------
    ;create a faster buffered graphics frame set for smoother gfx object movements
    _GDIPlus_Startup()                                                                        ;initialize GDI+
    Local $hBitmap = _GDIPlus_BitmapCreateFromScan0($arr[0],$arr[1])                          ;create an empty bitmap
    $ref_hHBITMAP = _GDIPlus_BitmapCreateHBITMAPFromBitmap($hBitmap)                          ;convert GDI+ bitmap to GDI bitmap
    _GDIPlus_BitmapDispose($hBitmap)                                                          ;delete GDI+ bitmap because not needed anymore
    $ref_hDC = _WinAPI_GetDC($ref_hWnd)                                                       ;get device context from GUI
    $ref_hDC_Backbuffer = _WinAPI_CreateCompatibleDC($ref_hDC)                                ;creates a memory device context compatible with the specified device
    $ref_oDC_Obj = _WinAPI_SelectObject($ref_hDC_Backbuffer, $ref_hHBITMAP)                   ;selects an object into the specified device context
    $ref_hGfxCtxt = _GDIPlus_GraphicsCreateFromHDC($ref_hDC_Backbuffer)                       ;create a graphics object from a device context (DC)
;    _GDIPlus_GraphicsSetSmoothingMode($ref_hGfxCtxt, $GDIP_SMOOTHINGMODE_HIGHQUALITY)           ;set smoothing mode (8 X 4 box filter)
;    _GDIPlus_GraphicsSetPixelOffsetMode($ref_hGfxCtxt, $GDIP_PIXELOFFSETMODE_HIGHQUALITY)
    $ref_hPen = _GDIPlus_PenCreate()                                                          ;create a pen object
    GUISetState(@SW_SHOW, $ref_hWnd)

#cs
           $g_framelabel = GUICtrlCreateLabel("Press ESC to Exit",0,0,100,100) ; it's global because adlib needs to access it
           GUICtrlSetBkColor($g_framelabel,$GUI_BKCOLOR_TRANSPARENT)
           GUICtrlSetColor($g_framelabel,0x00ff00)
           AdlibRegister ( "FrameCounterUpdate" , 1000 )
           GUICtrlCreateLabel("Click MB2 to toggle camera mode. While unlocked, push cursor against screen edge to move camera, hold MB3 to pan camera, hold MB1 to drag camera.",(@DeskTopWidth-600)/2,@DeskTopHeight-40,600,40,$SS_Center)
           GUICtrlSetBkColor(-1,$GUI_BKCOLOR_TRANSPARENT)
           GUICtrlSetColor(-1,0x00ff00)
           GUICtrlSetFont (-1, 12)
#ce

; experimental huge cursor
; TODO: Seems that even larger cursors are possible if not loading from .cur https://stackoverflow.com/questions/70704210/is-a-cursor-greater-than-512x512-pixels-in-size-possible 
; https://stackoverflow.com/questions/46014692/windows-cursor-size-bigger-than-maximum-available
; https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-loadimagea no need to specify size if not requesting defaultsize
Global $hWhiteCursor = DllCall($user32dll,"handle","LoadImage", "handle", Null, "str", @ScriptDir & "\assets\cursors\white.cur", "uint", 2, "int", 0, "int", 0, "uint", 0x00000010)
Global $hLimeCursor = DllCall($user32dll,"handle","LoadImage", "handle", Null, "str", @ScriptDir & "\assets\cursors\lime.cur", "uint", 2, "int", 0, "int", 0, "uint", 0x00000010)
Global $hCyanCursor = DllCall($user32dll,"handle","LoadImage", "handle", Null, "str", @ScriptDir & "\assets\cursors\cyan.cur", "uint", 2, "int", 0, "int", 0, "uint", 0x00000010)
Global $hYellowCursor = DllCall($user32dll,"handle","LoadImage", "handle", Null, "str", @ScriptDir & "\assets\cursors\yellow.cur", "uint", 2, "int", 0, "int", 0, "uint", 0x00000010)
GUIRegisterMsg($WM_SETCURSOR,OnMessage)
    Return $arr
EndFunc

Func DemoWinddownProcedure(ByRef $ref_hWnd, ByRef $ref_hHBITMAP, ByRef $ref_hDC, ByRef $ref_hDC_Backbuffer, ByRef $ref_oDC_Obj, ByRef $ref_hGfxCtxt, ByRef $ref_hPen, ByRef $mouse)
     AdlibUnRegister ( "FrameCounterUpdate" )
     FrameCounterSingleton(False, Null)

     _GDIPlus_PenDispose($ref_hPen)
     _WinAPI_SelectObject($ref_hDC_Backbuffer, $ref_oDC_Obj)
     _GDIPlus_GraphicsDispose($ref_hGfxCtxt)
     _WinAPI_DeleteObject($ref_hHBITMAP)
     _WinAPI_ReleaseDC($ref_hWnd, $ref_hDC)

     GUIDelete($ref_hWnd)
     RestorePointerSpeedAndAccel($mouse)

GUIRegisterMsg($WM_SETCURSOR,"")
Local $delWhite = DllCall($user32dll,"bool","DestroyCursor","handle",$hWhiteCursor[0])
Local $delLime = DllCall($user32dll,"bool","DestroyCursor","handle",$hLimeCursor[0])
Local $delCyan = DllCall($user32dll,"bool","DestroyCursor","handle",$hCyanCursor[0])
Local $delYellow = DllCall($user32dll,"bool","DestroyCursor","handle",$hYellowCursor[0])
;MsgBox(0,"",$delWhite[0] & "," & $delLime[0] & "," & $delCyan[0] & "," & $delYellow[0])
EndFunc



Func DemoDrawRoutine(Const $ctx, Const $pen, Const $width, Const $height)
     Local Static $statePtr = DemoSingletonState()
     Local $lineXpos, $lineYpos, $modceil
     Local $currentX = DllStructGetData($statePtr,"x")
     Local $currentY = DllStructGetData($statePtr,"y")
     Local $currentZ = DllStructGetData($statePtr,"z")
     Local $currentColor = DllStructGetData($statePtr,"color")
     Local $modunit = DllStructGetData($statePtr,"gridsize")

                   _GDIPlus_GraphicsClear($ctx)                                                    ; sets canvas to black
                   _GDIPlus_PenSetWidth($pen, 1)                                                   ; set pen size
                   _GDIPlus_PenSetColor($pen, 0xFF808080)                                          ; grey grid
                   $modceil = $modunit*ceiling($height/$modunit/2)                                 ; how many whole grid units needed to cover the window
                   for $i=-$modceil to $modceil step $modunit
                       $lineYpos = $height/2+$i - mod($currentY,$modunit)
;                       $lineYpos = Mod(Mod($i-$currentY,$modceil)+$modceil,$modceil)
                       _GDIPlus_GraphicsDrawLine($ctx, 0, $lineYpos,  $width-1, $lineYpos, $pen)   ; horizontal lines, from 0 to width-1 at ypos
                   next
                   $modceil = $modunit*ceiling($width/$modunit/2)                                  ; how many whole grid units needed to cover the window
                   for $i=-$modceil to $modceil step $modunit
                       $lineXpos = $width/2+$i - mod($currentX,$modunit)
;                       $lineXpos = Mod(Mod($i-$currentX,$modceil)+$modceil,$modceil)
                       _GDIPlus_GraphicsDrawLine($ctx, $lineXpos, 0, $lineXpos, $height-1, $pen)   ; vertical lines, from 0 to height-1 at xpos
                   next
#cs
                   _GDIPlus_PenSetColor($pen, $currentColor)                                       ; xhair color
                   _GDIPlus_GraphicsDrawLine($ctx,        0, $height/2,   $width, $height/2, $pen)
                   _GDIPlus_GraphicsDrawLine($ctx, $width/2,         0, $width/2,   $height, $pen)
#ce

EndFunc



Func Demo($toggle = null, $cursorlock=null)
     Local Static $ref_hWnd, $ref_hHBITMAP, $ref_hDC, $ref_hDC_Backbuffer, $ref_oDC_Obj, $ref_hGfxCtxt, $ref_hPen
     Local Static $imgDim[4], $aPoint[3][2], $mouse=[10, 0, 0, 0] , $renderUnlocked=false
     Local Static $submodebackup=3
     if $toggle then ; this must be checked before the render case, because $renderunlocked is stateful
        if $renderUnlocked then ; end the demo
           $renderUnlocked = false ; do this first in case main loop calls
           _MouseTrap()
           DemoWinddownProcedure($ref_hWnd, $ref_hHBITMAP, $ref_hDC, $ref_hDC_Backbuffer, $ref_oDC_Obj, $ref_hGfxCtxt, $ref_hPen, $mouse )
           SetDeviceSubscriptionMode($submodebackup)
        else                    ; start the demo
           $submodebackup = GetDeviceSubscriptionMode()
           SetDeviceSubscriptionMode(3+BitAND(4,$submodebackup))
           Local $arr = DemoStartupProcedure( $ref_hWnd, $ref_hHBITMAP, $ref_hDC, $ref_hDC_Backbuffer, $ref_oDC_Obj, $ref_hGfxCtxt, $ref_hPen, $mouse )
           $imgDim[0]=$arr[0]
           $imgDim[1]=$arr[1]
           $imgDim[2]=$arr[2]
           $imgDim[3]=$arr[3]
$aPoint[0][0] = 0
$aPoint[0][1] = 0
$aPoint[1][0] = $arr[0]
$aPoint[1][1] = 0
$aPoint[2][0] = 0
$aPoint[2][1] = $arr[1]
           $g_mousetrap_bound[0]=$imgDim[2]
           $g_mousetrap_bound[1]=$imgDim[3]
           $g_mousetrap_bound[2]=$imgDim[0]+$imgDim[2]
           $g_mousetrap_bound[3]=$imgDim[1]+$imgDim[3]
           _MouseTrap(Int($imgDim[2]+$imgDim[0]/2),Int($imgDim[3]+$imgDim[1]/2),Int($imgDim[2]+$imgDim[0]/2)+1,Int($imgDim[3]+$imgDim[1]/2)+1)  ; lock to halflength positions of viewport
           GUISetCursor(16,1)
           DllCall($user32dll, "handle", "SetCursor", "handle", $hLimeCursor[0])
           $renderUnlocked = true ; do this last
        endif
     elseif $renderUnlocked and $toggle=null then ; called from main loop. Note that we only run on main loop calls, otherwise the processing gets clogged
           DemoDrawRoutine($ref_hGfxCtxt, $ref_hPen, $imgDim[0], $imgDim[1]) ; might need to add in ways to alter the image dimensions upon notification, which involves resizing the buffer allocation too and not just changing numbers
           _WinAPI_BitBlt($ref_hDC, 0, 0, $imgDim[0],$imgDim[1], $ref_hDC_Backbuffer, 0, 0, $SRCCOPY) ;copy backbuffer to screen (GUI)
;_WinAPI_PlgBlt($ref_hDC, $aPoint, $ref_hDC_backbuffer, 0, 0, $imgDim[0], $imgDim[1])
           FrameCounterSingleton()
     elseif not ($cursorlock=null) then ; lock/unlock cursor, need stateful data of window size/position. Low priority, latency doesn't matter so put it in elseif
         if $cursorlock then ; lock to center of screen
            _MouseTrap(Int($imgDim[2]+$imgDim[0]/2),Int($imgDim[3]+$imgDim[1]/2),Int($imgDim[2]+$imgDim[0]/2)+1,Int($imgDim[3]+$imgDim[1]/2)+1)
         else                ; lock to boundary of render
            _MouseTrap($g_mousetrap_bound[0], $g_mousetrap_bound[1], $g_mousetrap_bound[2], $g_mousetrap_bound[3])
         endif
     endif
     Return $renderUnlocked ; if called specifically with false then just queries state
EndFunc

Func FrameCounterSingleton($update=null, $ref_hWnd=null)
     Local Static $demowindow = null, $counter=0
     Switch $update
       Case True ; update framecounter display
            Local $accumulated = $counter
            $counter -= $accumulated
            WinSetTitle($demowindow, "", "Demo " & $accumulated & "fps (" & $g_rawinput_queued & "/" & $g_rawinput_maxindex+1 & ")" )
       Case False ; refresh reference
            $demowindow = $ref_hWnd
       Case Null ; add framecount
            $counter += 1
     EndSwitch
EndFunc

Func FrameCounterUpdate()
     FrameCounterSingleton(true)
EndFunc

Func PanCamera()
     Local Static $singleton_cache = DemoSingletonState()
     Local $cursorpos = MouseGetPos()
     Local $sendX = round(($cursorpos[0]-$g_middle_drag[0])/5)
     Local $sendY = round(($cursorpos[1]-$g_middle_drag[1])/5)
     MoveMouseDelta($sendX,$sendY,$singleton_cache)
EndFunc

Func CmdExitProgram()
     Exit
#cs
     Switch @GUI_WinHandle
       Case $g_hForm
            Exit
     EndSwitch
#ce
EndFunc


Func CmdScriptStartStop($start=null)
     Local Static $state = null
     Switch $start
       Case True
            $state = true
            Local $nowtime = _NowCalc()
            $gReportFileMkb = FileOpen("logs\" & _CleanupFileName($nowtime) & "\data.csv", 9)
            $gReportFileLst = FileOpen("logs\" & _CleanupFileName($nowtime) & "\list.txt", 9)
            FileWrite($gReportFileMkb, "### NOTE: take the OS-provided timestamp with a grain of salt, as they are only reported in 16 or 10 ms increments. To get accurate interrupt timing of GetMessage() returns, use QueryPerformanceCounter instead. ###" & @CRLF)
            FileWrite($gReportFileLst, _
                                         "================" & @CRLF & _
                                         "Initial HID List" & @CRLF & _
                                         "================" & @CRLF & _
                                         GetConnectedRawinputDevicesInfoString() & @CRLF & _
                                         "---------------- Recording Starts ----------------" & @CRLF)
            UpdateList("== " & $i18n_devicechange_title & " ==" & @CRLF, True)
            RawinputStateController(true)
            CmdSuspend($g_hForm, false)
       Case False
            $state = false
            CmdSuspend($g_hForm)
            RawinputStateController(false)
            FileClose($gReportFileMkb)
            FileClose($gReportFileLst)
     EndSwitch
     return $state
EndFunc

Func CmdUnlockProcessing($state, $hWnd = $g_hForm)
;     GUIRegisterMsg( $WM_INPUT, '' )
     OnMessage($hWnd, $WM_NOTIFY, null, $state)
;     If $state then GUIRegisterMsg( $WM_INPUT, OnMessage )
EndFunc

Func CmdDemoQuit()
     if CmdScriptStartStop() then CmdScriptStartStop(false) ; command script to stop
     if Demo(false) then Demo(true)           ; toggle to close demo
EndFunc


Func CmdDemoInit()
     if CmdScriptStartStop() then CmdScriptStartStop(false) ; command script to stop first
     if Demo(false) then Demo(true)           ; if demo is running, toggle to close it first
     Demo(true)                               ; toggle to actually launch the demo
     CmdScriptStartStop(true)                        ; start listening
EndFunc

Func CmdSuspend($hWnd, $stop=null)
     Switch $stop
       Case True  ; force suspend
            CmdUnlockProcessing(false, $hWnd)
            GUICtrlSetState($g_suspend_button,$GUI_ENABLE)
            GUICtrlSetData($g_suspend_button, $i18n_resume_buttontext)
            GUICtrlSetData($g_toggle_button,$i18n_active_buttontext)
            WinSetTitle($hWnd, "", $i18n_suspended_status & $i18n_program_title_suffix)
            ControlEnable($hWnd, "", $g_label)
            ControlEnable($hWnd, "", $g_log)
            ControlEnable($hWnd, "", $g_mouse_checkbox)
            ControlEnable($hWnd, "", $g_keybd_checkbox)
            ControlEnable($hWnd, "", $g_hidev_checkbox)
       Case False ; force unsuspend
            CmdUnlockProcessing(true, $hWnd)
            GUICtrlSetState($g_suspend_button,$GUI_ENABLE)
            GUICtrlSetData($g_suspend_button, $i18n_suspend_buttontext)
            GUICtrlSetData($g_toggle_button,$i18n_active_buttontext)
            WinSetTitle($hWnd, "", $i18n_active_status & $i18n_program_title_suffix)
            ControlDisable($hWnd, "", $g_label)
            ControlDisable($hWnd, "", $g_log)
            ControlDisable($hWnd, "", $g_mouse_checkbox)
            ControlDisable($hWnd, "", $g_keybd_checkbox)
            ControlDisable($hWnd, "", $g_hidev_checkbox)
       Case Else  ; initialize state
            CmdUnlockProcessing(false, $hWnd)
            GUICtrlSetState($g_suspend_button,$GUI_DISABLE)
            GUICtrlSetData($g_suspend_button, $i18n_suspend_buttontext)
            GUICtrlSetData($g_toggle_button,$i18n_inactive_buttontext)
            WinSetTitle($hWnd, "", $i18n_inactive_status & $i18n_program_title_suffix)
            ControlEnable($hWnd, "", $g_label)
            ControlEnable($hWnd, "", $g_log)
            ControlEnable($hWnd, "", $g_mouse_checkbox)
            ControlEnable($hWnd, "", $g_keybd_checkbox)
            ControlEnable($hWnd, "", $g_hidev_checkbox)
     EndSwitch
EndFunc

Func GUICmdScriptToggle()
     Local Static $lock = false
     if $lock then return
     $lock = not $lock
     CmdScriptStartStop( GUICtrlRead(@GUI_CTRLID) = $i18n_inactive_buttontext )
     $lock = not $lock
EndFunc



Func GUICmdDemoButton()
     Local Static $lock = false, $state = false
     if $lock then return
     $lock = not $lock
     $state = not $state
     if $state then
        GUISetState(@SW_DISABLE,@GUI_WinHandle)
        CmdDemoInit()
        WinSetTitle(@GUI_WinHandle, "", $i18n_demorunning_status & $i18n_program_title_suffix)
     else
        CmdDemoQuit()
        GUISetState(@SW_ENABLE,@GUI_WinHandle)
        GUISetState(@SW_RESTORE,@GUI_WinHandle)
        WinSetTitle(@GUI_WinHandle, "", $i18n_inactive_status & $i18n_program_title_suffix)
     endif
     $lock = not $lock
EndFunc

Func GUICmdSuspendButton()
     CmdSuspend( @GUI_WinHandle , GUICtrlRead(@GUI_CTRLID) = $i18n_suspend_buttontext )
EndFunc

#cs
Func GUICmdDeviceButton()
    Local Static $lock = false
    if $lock then return
    $lock = not $lock

       local $scriptrunning = CmdScriptStartStop()
       if $scriptrunning then CmdSuspend(@GUI_WinHandle, true)
        Run(@AutoItExe & ' "' & @ScriptFullPath & '" HID_LIST_DISPLAY')
       if $scriptrunning then CmdSuspend(@GUI_WinHandle, false)

    $lock = not $lock
EndFunc
#ce


Func GUICmdDeviceButton()
    Local Static $handle=null, $lock = false
    if $lock then return
    $lock = not $lock

    if $handle=null then 

       local $scriptrunning = CmdScriptStartStop()
       if $scriptrunning then CmdSuspend(@GUI_WinHandle, true)
       $handle=GUICreate($i18n_deviceinfo_wintitle,700,600,450,0,BitXOR($WS_POPUPWINDOW,$WS_BORDER) + $WS_SIZEBOX, $WS_EX_MDICHILD, @GUI_WinHandle)
       Local $ctrledit = GUICtrlCreateEdit(GetConnectedRawinputDevicesInfoString(), 0, 0, 700, 600, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_AUTOHSCROLL + $WS_HSCROLL + $ES_READONLY)
;       Local $ctrledit = GUICtrlCreateEdit(GetConnectedRawinputDevicesInfoString(), 0, 0, 700, 600, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_READONLY)
       GUISwitch(@GUI_WinHandle) ; immediately switch back to main window in case dummy gets queued

; disable context menu by subclassing per https://www.autoitscript.com/forum/topic/183294-disable-right-click-on-control/?do=findComment&comment=1316532
  Local Static $pEditCallback = DllCallbackGetPtr( DllCallbackRegister( "EditCallback", "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr" ) )
  Local $hMyedit = GUICtrlGetHandle( $ctrledit )
  _WinAPI_SetWindowSubclass( $hMyedit, $pEditCallback, 1, 0 ) ; $iSubclassId = 1, $pData = 0

       GUICtrlSetFont($ctrledit, 9, 0, 0, "Consolas")
       GUICtrlSetResizing($ctrledit, $GUI_DOCKBORDERS)
       GUISetState(@SW_SHOW,$handle)
       GUISetState(@SW_RESTORE,@GUI_WinHandle)
       if $scriptrunning then CmdSuspend(@GUI_WinHandle, false)

    else

       GUIDelete($handle) ; handle never leaves function, no need to worry about being altered in other places
       $handle=null

    endif

    $lock  = not $lock
EndFunc


Func GetDeviceSubscriptionMode()
     Local $devflag = 0
     if GUICtrlRead($g_mouse_checkbox) = $GUI_CHECKED then $devflag += 1
     if GUICtrlRead($g_keybd_checkbox) = $GUI_CHECKED then $devflag += 2
     if GUICtrlRead($g_hidev_checkbox) = $GUI_CHECKED then $devflag += 4
     Return $devflag
EndFunc

Func SetDeviceSubscriptionMode($flag=3)
     Local $devflag = GetDeviceSubscriptionMode()
     GUICtrlSetState($g_mouse_checkbox, $GUI_UNCHECKED)
     GUICtrlSetState($g_keybd_checkbox, $GUI_UNCHECKED)
     GUICtrlSetState($g_hidev_checkbox, $GUI_UNCHECKED)
     if BitAND($flag,1) then GUICtrlSetState($g_mouse_checkbox, $GUI_CHECKED)
     if BitAND($flag,2) then GUICtrlSetState($g_keybd_checkbox, $GUI_CHECKED)
     if BitAND($flag,4) then GUICtrlSetState($g_hidev_checkbox, $GUI_CHECKED)
     Return $devflag
EndFunc
