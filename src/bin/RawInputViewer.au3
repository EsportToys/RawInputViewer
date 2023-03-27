#NoTrayIcon
#include <APISysConstants.au3>
#include <GUIConstantsEx.au3>
#Include <WinAPI.au3>
#include <WinAPIRes.au3>
#include <WinAPISys.au3>
#include <WinAPIHObj.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <ColorConstantS.au3>
#include <EditConstants.au3>
#include <Array.au3>
#include <Math.au3>
#include <Date.au3>
#include <Misc.au3>
#include "mischelper.au3"
#include "hidhelpers.au3"
#include "i18n.au3"
#include "cmdline.au3"
#include "rawhelpers.au3"
#include "winapihelpers.au3"
#include "gdihelpers.au3"
#include "demo.au3"

Global Const $GLOBAL_OPTIONS_INI_PATH = "options.ini"
Global Const $GLOBAL_PROGRAM_WINDOW_TITLE = "RawInputViewer"
Global Const $GLOBAL_PROGRAM_ICON_PATH = "%SystemRoot%\System32\joy.cpl"
Global Const $GLOBAL_MAXIMUM_BUFFER_SIZE = 256
Global Const $GLOBAL_INITIAL_XHAIR_COLOR = 0xff00ff00
Global Const $GLOBAL_INITIAL_GRIDSIZE = 320
Global Const $user32dll = DllOpen("user32.dll")
Global Const $kernel32dll = DllOpen('kernel32.dll')
Global Const $gdi32dll = DllOpen('gdi32.dll')
Global Const $PERFORMANCE_FREQUENCY = QueryPerformanceFrequency()


If $CMDLINE[0] > 0 then CmdLineHandler($CMDLINE)



If _Singleton( $GLOBAL_PROGRAM_WINDOW_TITLE , 1 ) = 0 Then
   WinActivate($GLOBAL_PROGRAM_WINDOW_TITLE)
   Exit
Else
   opt("GUICloseOnESC",0)
   opt("GUIOnEventMode", 1)
;   opt("GUIEventOptions", 1)      ; manually process min/maximize/resize/store cmds
   opt("MustDeclareVars", 1)
   opt("WinWaitDelay",0)
   opt("SendKeyDelay",0)          ; delay between multiple Send commands
   opt("SendKeyDownDelay",0)      ; duration of each Send keystroke (key hold time)
   opt("MouseClickDelay",0)       ; delay between multiple mouseclick commands
   opt("MouseClickDownDelay",0)   ; duration of each mouseclick command (button hold time)
   initialize_i18n_strings($GLOBAL_OPTIONS_INI_PATH)
EndIf

Global $gReportFileMkb, $gReportFileLst

Global Const $g_msg_subscription_list = [$WM_INPUT, $WM_INPUT_DEVICE_CHANGE, $WM_MOVING, $WM_SIZE, $WM_ENTERMENULOOP, $WM_SYSCOMMAND]
Global Const $g_hForm = GUICreate($i18n_inactive_status & $i18n_program_title_suffix, 430, 600, -1, -1, BitOr($WS_CAPTION,$WS_POPUPWINDOW))
Global Const $g_toggle_button = GUICtrlCreateButton($i18n_inactive_buttontext, 15, 10, 100, 25)
Global Const $g_suspend_button = GUICtrlCreateButton($i18n_suspend_buttontext, 115, 10, 100, 25)
GUICtrlSetState($g_suspend_button,$GUI_DISABLE)
Global Const $g_device_button = GUICtrlCreateButton($i18n_devices_buttontext, 215, 10, 100, 25)
Global Const $g_demo_button = GUICtrlCreateButton($i18n_demo_buttontext, 315, 10, 100, 25)
Global Const $g_mouse_checkbox = GUICtrlCreateCheckbox($i18n_mouse_checkbox, 15, 35, 100, 35)
GUICtrlSetState($g_mouse_checkbox, $GUI_CHECKED)
Global Const $g_keybd_checkbox = GUICtrlCreateCheckbox($i18n_keyboard_checkbox, 115, 35, 100, 35)
GUICtrlSetState($g_keybd_checkbox, $GUI_CHECKED)
Global Const $g_hidev_checkbox = GUICtrlCreateCheckbox($i18n_hid_checkbox, 215, 35, 200, 35)
Global Const $g_label = GUICtrlCreateEdit($i18n_clicktostart_title & @CRLF, 15, 70, 400, 275, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_READONLY)
GUICtrlSetFont($g_label, 9, 0, 0, "Consolas")
Global Const $g_log = GUICtrlCreateEdit("== " & $i18n_devicechange_title & " ==" & @CRLF, 15, 360, 400, 230, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_READONLY)
GUICtrlSetFont($g_log, 9, 0, 0, "Consolas")

ProgramCommand("init_refresh")
InitializeEventListener()
InitializeGlobalBuffer(true)
RegisterWindowMessagesToCentralHandler($g_msg_subscription_list) ; make sure this is done after initializations so that WM_* messages don't start coming in before the handler buffers are initialized

GUICtrlSetOnEvent($g_toggle_button, GUICmdScriptToggle)
GUICtrlSetOnEvent($g_suspend_button, GUICmdSuspendButton)
GUICtrlSetOnEvent($g_device_button, GUICmdDeviceButton)
GUICtrlSetOnEvent($g_demo_button, GUICmdDemoButton)
GUISetOnEvent(-3, CmdExitProgram)

SetProcessDPIAware()
GUISetIcon($GLOBAL_PROGRAM_ICON_PATH)
GUISetState(@SW_SHOW,$g_hForm)
UpdateText("", $g_label) ; inform function of the handle to the editctrl for input message
UpdateList("", null, $g_log)   ; inform function of the handle to the editctrl for input device change
Main()

Func SetProcessDPIAware()
     Local $h=GUICreate('')
     DllCall("user32.dll", "bool", "SetProcessDPIAware")
     GUIDelete($h)
EndFunc

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
     GUIRegisterMsg($msg, WndProc)
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
        $g_eventListenerArgs[$i] = DllStructCreate('hwnd hWnd;uint message;wparam wParam;lparam lParam;dword time;dword pt;lparam info;int64 qpc;')
        $g_eventListener[$i] = GUICtrlCreateDummy()
        GUICtrlSetOnEvent($g_eventListener[$i], EventCallbackHandler)
    Next
EndFunc

Func InitializeGlobalBuffer($firstUse=false)                        ; reset timer in the function
    if not $firstuse then InitializeDummyBuffer($gid_on_wm_input)   ; clear dummy buffer if this is not first-time use
    Global $g_rawinput_maxindex = 63
    Global $gid_on_wm_input[$g_rawinput_maxindex+1]
    Global $g_rawinput_buffer[$g_rawinput_maxindex+1][3]
    Global $g_device_list = []
    Global $g_rawinput_queued = 0
    GUISwitch($g_hForm)
    InitializeDummyBuffer($gid_on_wm_input,true)
    For $i=0 to $g_rawinput_maxindex 
        $g_rawinput_buffer[$i][2] = DllStructCreate('hwnd hWnd;uint message;wparam wParam;lparam lParam;dword time;dword pt;lparam info;int64 qpc;')
    Next
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

Func MakeMessage($h,$m,$w,$l,$q)
     Local $_ = DllStructCreate('hwnd hWnd;uint message;wparam wParam;lparam lParam;dword time;dword pt;lparam info;int64 qpc;')
     WriteMessage($h,$m,$w,$l,$q,$_)
     Return $_
EndFunc

Func WriteMessage($h,$m,$w,$l,$q,ByRef $_)
     $_.hWnd = $h
     $_.message = $m 
     $_.wParam = $w 
     $_.lParam = $l 
     $_.time = DllCall($user32dll, 'long', 'GetMessageTime')[0]
     $_.pt = DllCall($user32dll, 'dword', 'GetMessagePos')[0]
     $_.info = DllCall($user32dll, 'lparam', 'GetMessageExtraInfo')[0]
     $_.qpc = $q
EndFunc

Func WndProc($h,$m,$w,$l)
     local static $buffer_index = 0, $isRecording=false
     local $q = QueryPerformanceCounter($kernel32dll)
     Switch $m
       Case 0xFF ; WM_INPUT
            If $isRecording Then 
               If Demo(False) Then
                  ImmediateRawinput(MakeMessage($h,$m,$w,$l,$q))
               Else
                  DeferredRawinput(MakeMessage($h,$m,$w,$l,$q))
               EndIf
            EndIf
            Return 0
       Case 0xFE ; WM_INPUT_DEVICE_CHANGE
            ForwardTimestampedMsg(Process_Device_Change, MakeMessage($h,$m,$w,$l,$q))
            Return 0
       Case $WM_NOTIFY
            $isRecording = Main($l)
       Case $WM_SYSCOMMAND
            If $isRecording then return ($w=0xF060 ? $GUI_RUNDEFMSG : 0) ; always return 0 except for the close window message
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

Func ForwardTimestampedMsg($func, $struct)
     $g_eventListenerQueued += QueueEvent($func, $struct)
EndFunc

Func DeferredRawinput($struct)
     $g_rawinput_queued += WriteToRawinputBuffer($struct)
EndFunc

Func EventCallbackHandler()
     local $index = GUICtrlRead(@GUI_CTRLID)
     local $func = $g_eventListenerFunctions[$index]
     local $args = $g_eventListenerArgs[$index]
     $g_eventListenerStatus[$index] = false
     $g_eventListenerQueued -= 1
     $func($args)
EndFunc

Func Callback_WM_INPUT()
     local $index = GUICtrlRead(@GUI_CTRLID)
     local $data = $g_rawinput_buffer[$index][1]
     local $misc = $g_rawinput_buffer[$index][2]
     $g_rawinput_buffer[$index][0] = false
     $g_rawinput_queued -= 1
     Process_Rawinput_Data($data, $misc)
EndFunc

Func QueueEvent($func, $args)
     Local $time = $args.time
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

Func ImmediateRawinput($misc)
     Process_Rawinput_Data(_RawInputFetchData($misc.lParam, $user32dll),$misc)
EndFunc

Func WriteToRawinputBuffer($misc)
     Local Static $buffer_index = 0
     Local $inputsWritten, $data = _RawInputFetchData($misc.lParam, $user32dll)
     If Not IsDllStruct($data) Then 
        FileWrite($gReportFileMkb, "FAILED FETCH AT T=" & $misc.time & @CRLF)
        $inputsWritten = 0
        Return $inputsWritten
     EndIf
     $buffer_index = _Min($buffer_index, $g_rawinput_maxindex)
     local $i, $j = $buffer_index, $k = $g_rawinput_maxindex
     if $g_rawinput_queued<$GLOBAL_MAXIMUM_BUFFER_SIZE then          ; if the number of queued events isn't full, scan buffer to check that it's not already occupied
        For $i = 0 To $k                                             ; loop through the buffer once, submit and return if found an empty slot
            if $g_rawinput_buffer[$j][0] then
               $j = Mod($j+1, $k+1)
            else
               $g_rawinput_buffer[$j][0] = true
               $g_rawinput_buffer[$j][1] = $data
               $g_rawinput_buffer[$j][2] = $misc
               GUICtrlSendToDummy($gid_on_wm_input[$j], $j)
               $buffer_index = Mod($j+1, $k+1)
               $inputsWritten = 1 
               Return $inputsWritten
            endif
        Next
        Return ExpandDummyBuffer($data, $misc)                   ; if no empty slot is found after one loop, expand the buffer by 1, and report that 1 message has been added
     else                                                        ; if buffer cannot be expanded further, simply look for any stale report to overwrite, and report that one has been overwritten
        For $i = 0 To $k
            if ($g_rawinput_buffer[$j][2]).time>=$misc.time then ; if report is fresher than current, don't overwrite
               $j = Mod($j+1, $k+1)
            else
               $g_rawinput_buffer[$j][0] = true
               $g_rawinput_buffer[$j][1] = $data
               $g_rawinput_buffer[$j][2] = $misc
               GUICtrlSendToDummy($gid_on_wm_input[$j], $j)
               $buffer_index = Mod($j+1, $k+1)
               $inputsWritten = 1                                ; even though it's overwritten, the previously written but stale event is still already queued, so eventually it will clear its own count, thus us adding one new event will invariably increase the number of events queued to the Autoit engine
               Return $inputsWritten
            endif
        Next
        FileWrite($gReportFileMkb, "DROPPED INPUT AT T=" & $misc.time & @CRLF)
     endif
     $inputsWritten = 0
     Return $inputsWritten
EndFunc

Func ExpandDummyBuffer($tRIM, $misc)
     Local $oldmaxindex = $g_rawinput_maxindex
     ReDim $g_rawinput_buffer[$oldmaxindex+2][3]
     $g_rawinput_buffer[$oldmaxindex+1][0] = true
     $g_rawinput_maxindex += 1
     if $oldmaxindex+1 = $g_rawinput_maxindex then
        GUISwitch($g_hForm)
        Local $dummyindex = _ArrayAdd($gid_on_wm_input, GUICtrlCreateDummy())
        GUICtrlSetOnEvent( $gid_on_wm_input[$dummyindex], "Callback_WM_INPUT")
        $g_rawinput_buffer[$oldmaxindex+1][1] = $tRIM
        $g_rawinput_buffer[$oldmaxindex+1][2] = $misc
        GUICtrlSendToDummy($gid_on_wm_input[$dummyindex], $oldmaxindex+1)
        return 1
     else
        MsgBox(0,"Error: race condition has occurred" & @error,"Message added at index " & $oldmaxindex+1 & ", but new max index is " & $g_rawinput_maxindex)
        Exit
     endif
EndFunc

Func RawinputStateController($enable=null)
     Local Const $defaultregistry = [[]]
     Local Static $registeredusages=$defaultregistry
     Switch $enable
       Case True
            InitializeGlobalBuffer()
            $registeredusages = GetConnectedRawinputDevicesUsages(GetDeviceSubscriptionMode())
            For $i=0 to UBound($registeredusages,1)-1
               _RawInputRegisterDevice($registeredusages[$i][0], $registeredusages[$i][1], 0x00002100, $g_hForm)
            Next
       Case False
            For $i=0 to UBound($registeredusages,1)-1
               _RawInputRegisterDevice($registeredusages[$i][0], $registeredusages[$i][1], 0x00000001, Null)
            Next
            $registeredusages=$defaultregistry
       Case Else
            Return $registeredusages
     EndSwitch
EndFunc

Func Process_Device_Change($msg)
     GUIRegisterMsg( 0xFF, '' ) ; halt inflow of rawinput messages without changing system state
     Local $p = DllStructCreate('short x;short y',DllStructGetPtr($msg,'pt'))
     Local $add = ($msg.wParam-1) ? (false) : (true)
     Local $filelog, $logstring = ( ($add) ? ("+") : ("-") ) & Hex($msg.lParam) & " (t=" & $msg.time & ", x=" & $p.x & ", y=" & $p.y & ")" & @CRLF
     UpdateList($logstring)
     FileWrite($gReportFileMkb, MakeLogString(Null,$msg))
     If $add Then 
        FileWrite($gReportFileLst, @CRLF & "==============" & @CRLF & " GIDC_ARRIVAL " & @CRLF & "==============" & @CRLF & GetConnectedRawinputDevicesInfoString($msg.lParam) & @CRLF)
     Else
        FileWrite($gReportFileLst, @CRLF & "==============" & @CRLF & " GIDC_REMOVAL " & @CRLF & "==============" & @CRLF & "Handle: 0x" & Hex($msg.lParam,16) & @CRLF)
     EndIf
     GUIRegisterMsg( 0xFF,  WndProc) ; restore inflow of rawinput messages
EndFunc


Func Process_Rawinput_Data($raw, $misc)
     Local $_ = RAWINPUT($raw)
     Local $t = $misc.time
     Local Static $p = DllStructCreate('short x;short y')
     Local Static $write = DllStructCreate('dword;',DllStructGetPtr($p))
     DllStructSetData($write,1,$misc.pt)
     If Demo(false) Then
        Switch $_.Type
          Case 0
               local static $alttabbed=false
               if $_.wParam then                                                                         ; as soon as one in-background report is received, we know we are alt-tabbed
                  $alttabbed = true                                                                      ; keep setting it to true, even as you receive them
               else                                                                                      ; window restore check
                  if $alttabbed then                                                                     ; if was alttabbed but now are receiving foreground, then we are no longer alttabbed
                     $alttabbed = false                                                                  ; no longer alttabbed
                     CameraLockSetState()                                                                ; re-lock cursor accordingly
                     UpdateButtonState(2,0,0,0)
                  endif
                  if (not $_.Flags) and ($_.LastX or $_.LastY) then UpdateMovementCmd($_.LastX, $_.LastY, $p.x, $p.y, $_.hDevice) ; It is ok to move first before updating buttons, since you can't distinguish between the order witin the same report.
                  if $_.ButtonFlags then UpdateButtonState($_.ButtonFlags, $_.ButtonData, $p.x, $p.y, $_.hDevice)
               endif
          Case 1
               if not $_.wParam then
                    if $_.VKey = 0x1b then GUICmdDemoButton()
               endif
          Case 2
        EndSwitch
     Else
        UpdateText(MakeReportString($raw,$misc)) ; this only writes to static variable in the function without triggering update
     EndIf
     FileWrite($gReportFileMkb,MakeLogString($raw,$misc))

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
            FileWrite($gReportFileMkb, "### QueryPerformanceFrequency = " & $PERFORMANCE_FREQUENCY & " Hz ###" & @CRLF)
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
;     GUIRegisterMsg( 0xFF, '' )
     WndProc($hWnd, $WM_NOTIFY, null, $state)
;     If $state then GUIRegisterMsg( 0xFF, WndProc )
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
