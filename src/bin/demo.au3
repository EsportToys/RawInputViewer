#include <WinAPIGdi.au3>
#include <WinAPIGdiDC.au3>
#include <GDIPlus.au3>

Func UpdateMovementCmd($lLastX, $lLastY, $posX, $posY, $handle=null)
     Local Static $singleton_cache = DemoSingletonState() ; TODO: refactor DemoSingletonState to take device handle and return struct address, then change this line to Local instead of Local Static (and pass handle)
     Local $cameramode = DllStructGetData($singleton_cache, "camlock")
     Local $drag_state = DllStructGetData($singleton_cache, "draglock")
     Local $pan_state = DllStructGetData($singleton_cache, "panlock")
     Local $sendX=0, $sendY=0, $residueX=0, $residueY=0
        if $cameramode or $pan_state then   ; camlock mode true, FPS-like
           $sendX = $lLastX
           $sendY = $lLastY
        else                  ; camlock mode false, RTS-like
          if $drag_state then   
             ; drag pan
             $sendX = -$lLastX
             $sendY = -$lLastY
          else                 
             ; edge pan
             if ($posX+$lLastX<$singleton_cache.left) or ($posX+$lLastX>$singleton_cache.right-1) then $sendX=$lLastX
             if ($posY+$lLastY<$singleton_cache.top) or ($posY+$lLastY>$singleton_cache.bottom-1) then $sendY=$lLastY
          endif
        endif
        Local $fac =  PointerMultiplier(10,0,$singleton_cache.dpi)
        $sendX = $residueX + $sendX*$fac
        $sendY = $residueY + $sendY*$fac
        $residueX = $sendX - Int($sendX)
        $residueY = $sendY - Int($sendY)
        MoveMouseDelta(Int($sendX), Int($sendY), $singleton_cache)
EndFunc

Func UpdateButtonState($usButtonFlags, $usButtonData, $lastX, $lastY, $handle=null)
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
               SetCursor($hWhiteCursor, $user32dll)
          Case 0x0000ffff
               SetCursor($hCyanCursor, $user32dll)
          Case 0x00ffff00
               SetCursor($hYellowCursor, $user32dll)
          Case 0x0000ff00
               SetCursor($hLimeCursor, $user32dll)
        EndSwitch
     endif

     ; camera mode toggle check. Not latency-sensitive
     if BitAND($usButtonFlags,1) then DragLockSetState(true, $singleton_cache)
     if BitAND($usButtonFlags,2) then DragLockSetState(false, $singleton_cache)
     if BitAND($usButtonFlags,4) then CameraLockSetState(not $cameramode, $singleton_cache)
     if BitAND($usButtonFlags,16) then PanLockSetState(True,$lastX,$lastY,$singleton_cache)
     if BitAND($usButtonFlags,32) then PanLockSetState(False,$lastX,$lastY,$singleton_cache)
     if BitAND($usButtonFlags,1024) then ChangeZoomLevel($usButtonData, $singleton_cache)
EndFunc

Func CameraLockSetState($lock=Null,$target=Null)
     Local Static $cache=DemoSingletonState()
     Local $_ = IsDllStruct($target) ? $target : $cache
     Local $mode = $_.camlock
     If Not (Null=$lock) Then
        DllStructSetData($_, "camlock", $lock)
        $mode = $lock 
     EndIf
     If $mode Then
        _LockCursor(Int(($_.left+$_.right)/2),Int(($_.top+$_.bottom)/2),$user32dll) 
     Else
        _TrapCursor($_.left,$_.top,$_.right,$_.bottom,$user32dll)
     EndIf
EndFunc

Func DragLockSetState($lock, $ptr)
     DllStructSetData($ptr, "draglock", $lock)
EndFunc

Func PanLockSetState($lock, $x, $y, $_)
     DllStructSetData($_, "panlock", $lock)
     $_.panlock = $lock
     If $_.camlock Then Return
     If $lock Then
        _LockCursor($x,$y,$user32dll) 
     Else
        _TrapCursor($_.left,$_.top,$_.right,$_.bottom,$user32dll)
     EndIf
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
     Local Static $singleton_demo_state = DllStructCreate("long x;long y;long color;long z;long gridsize;boolean camlock;boolean draglock;boolean panlock;long left;long top;long right;long bottom;uint dpi")
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
    SplashTextOn ( "Please wait...", "Preparing buffer, please wait...", $arr[0],$arr[1],$arr[2],$arr[3],1)
    InitBigCursors($arr[0],$arr[1])
    SplashOff()
    DemoSingletonState(true) ; ask it to initialize state
    $ref_hWnd = GUICreate($i18n_demo_wintitle, $arr[0], $arr[1], $arr[2], $arr[3], 0x80000000)
    GUISetBkColor($COLOR_BLACK, $ref_hWnd)
    GUISetIcon($GLOBAL_PROGRAM_ICON_PATH)
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
    GUISetState(@SW_DISABLE, $g_hForm)
    GUISetState(@SW_SHOW, $ref_hWnd)
    GUIRegisterMsg($WM_SETCURSOR,WndProc)
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
     GUISetState(@SW_ENABLE, $g_hForm)
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



Func Demo($toggle = null)
     Local Static $ref_hWnd, $ref_hHBITMAP, $ref_hDC, $ref_hDC_Backbuffer, $ref_oDC_Obj, $ref_hGfxCtxt, $ref_hPen
     Local Static $imgDim[4], $mouse=[10, 0, 0, 0] , $renderUnlocked=false
     Local Static $submodebackup=3
     if $toggle then ; this must be checked before the render case, because $renderunlocked is stateful
        if $renderUnlocked then ; end the demo
           $renderUnlocked = false ; do this first in case main loop calls
           _FreeCursor()
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
           Local $demoState = DemoSingletonState()
           $demoState.dpi = GetDpiForWindow($ref_hWnd, $user32dll)
           $demoState.left = $imgDim[2]
           $demoState.top = $imgDim[3]
           $demoState.right = $imgDim[0]+$imgDim[2]
           $demoState.bottom = $imgDim[1]+$imgDim[3]
           _LockCursor(Int($imgDim[2]+$imgDim[0]/2),Int($imgDim[3]+$imgDim[1]/2),$user32dll)
           GUISetCursor(16,1,$ref_hWnd)
           SetCursor($hLimeCursor, $user32dll)
           $renderUnlocked = true ; do this last
        endif
     elseif $renderUnlocked and $toggle=null then ; called from main loop. Note that we only run on main loop calls, otherwise the processing gets clogged
           DemoDrawRoutine($ref_hGfxCtxt, $ref_hPen, $imgDim[0], $imgDim[1]) ; might need to add in ways to alter the image dimensions upon notification, which involves resizing the buffer allocation too and not just changing numbers
           _WinAPI_BitBlt($ref_hDC, 0, 0, $imgDim[0],$imgDim[1], $ref_hDC_Backbuffer, 0, 0, $SRCCOPY)
           FrameCounterSingleton()
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