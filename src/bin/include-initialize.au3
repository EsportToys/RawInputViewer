#NoTrayIcon
#include <APISysConstants.au3>
#include <GUIConstantsEx.au3>
#Include <WinAPI.au3>
#include <WinAPIRes.au3>
#include <WinAPISys.au3>
#include <WinAPIGdi.au3>
#include <WinAPIGdiDC.au3>
#include <WinAPIHObj.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <ColorConstantS.au3>
#include <EditConstants.au3>
#include <GDIPlus.au3>
#include <Array.au3>
#include <Math.au3>
#include <Date.au3>
#include <Misc.au3>
#include "mischelper.au3"
#include "hidhelpers.au3"
#include "i18n.au3"
#include "cmdline.au3"


Global Const $GLOBAL_OPTIONS_INI_PATH = "options.ini"
Global Const $GLOBAL_PROGRAM_WINDOW_TITLE = "RawInputViewer"
Global Const $GLOBAL_PROGRAM_ICON_PATH = "shell32_229.ico"
Global Const $GLOBAL_MAXIMUM_BUFFER_SIZE = 256
Global Const $GLOBAL_INITIAL_XHAIR_COLOR = 0xff00ff00
Global Const $GLOBAL_INITIAL_GRIDSIZE = 320


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

#cs ; sanbox for testing Autoit's hidden window
Global Const $g_console = WinGetHandle(AutoItWinGetTitle())
Global Const $g_console_box = ControlGetHandle($g_console,"","[CLASS:Edit; INSTANCE:1]")
_WinSetIcon($g_console,$GLOBAL_PROGRAM_ICON_PATH)
WinMove($g_console, "", Default, Default, 500, 500)
WinSetState($g_console, "", @SW_SHOW)
;ControlHide($g_console, "", $g_console_box);works
ControlDisable($g_console, "", $g_console_box)
ControlCommand($g_console, "", $g_console_box, "EditPaste", 'testnewline'&@CRLF)
ControlCommand($g_console, "", $g_console_box, "EditPaste", 'testnewline2'&@CRLF)
#ce

Global $g_framecounter=0, $g_framelabel = ""
Global $g_middle_drag[2], $g_mousetrap_bound[4]
Global $gReportFileMkb, $gReportFileLst

Global Const $g_msg_subscription_list = [$WM_INPUT, $WM_INPUT_DEVICE_CHANGE, $WM_MOVING, $WM_SIZE, $WM_ENTERMENULOOP, $WM_SYSCOMMAND]
;Global Const $g_hForm = GUICreate($i18n_inactive_status & $i18n_program_title_suffix, 450, 525, -1, -1, BitOr($WS_CAPTION,$WS_POPUPWINDOW))
Global Const $g_hForm = GUICreate($i18n_inactive_status & $i18n_program_title_suffix, 430, 600, -1, -1, BitOr($WS_CAPTION,$WS_POPUPWINDOW))
;GUISetBkColor($g_hForm,$COLOR_BLACK)
Global Const $g_toggle_button = GUICtrlCreateButton($i18n_inactive_buttontext, 15, 10, 100, 25)
Global Const $g_suspend_button = GUICtrlCreateButton($i18n_suspend_buttontext, 115, 10, 100, 25)
GUICtrlSetState($g_suspend_button,$GUI_DISABLE)
Global Const $g_device_button = GUICtrlCreateButton($i18n_devices_buttontext, 215, 10, 100, 25)
Global Const $g_demo_button = GUICtrlCreateButton($i18n_demo_buttontext, 315, 10, 100, 25)
Global Const $g_mouse_checkbox = GUICtrlCreateCheckbox("Mouse", 15, 35, 100, 35)
GUICtrlSetState($g_mouse_checkbox, $GUI_CHECKED)
Global Const $g_keybd_checkbox = GUICtrlCreateCheckbox("Keyboard", 115, 35, 100, 35)
GUICtrlSetState($g_keybd_checkbox, $GUI_CHECKED)
Global Const $g_hidev_checkbox = GUICtrlCreateCheckbox("Other Human-Interface Devices", 215, 35, 200, 35)
Global Const $g_label = GUICtrlCreateEdit($i18n_clicktostart_title & @CRLF, 15, 70, 400, 275, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_READONLY)
GUICtrlSetFont($g_label, 9, 0, 0, "Consolas")
;Global Const $g_log = GUICtrlCreateEdit("== " & $i18n_devicechange_title & " ==" & @CRLF, 25, 350, 400, 150, $ES_AUTOVSCROLL + $WS_VSCROLL + $ES_READONLY)
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
GUISetOnEvent($GUI_EVENT_CLOSE, CmdExitProgram)

GUISetIcon($GLOBAL_PROGRAM_ICON_PATH)

DllCall("User32.dll", "bool", "SetProcessDPIAware")
GUISetState(@SW_SHOW,$g_hForm)
UpdateText("", $g_label) ; inform function of the handle to the editctrl for input message
UpdateList("", null, $g_log)   ; inform function of the handle to the editctrl for input device change
Main()
