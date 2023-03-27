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

Func DemoStartupProcedure(ByRef $ref_hWnd, ByRef $mouse)
    Local $arr[4]
    $arr[0] = ProgramCommand("demo_render_width")
    $arr[1] = ProgramCommand("demo_render_height")
    $arr[0] = $arr[0]>640?round($arr[0]):640
    $arr[1] = $arr[1]>480?round($arr[1]):480
    $arr[2] = round((@DeskTopWidth-$arr[0])/2)
    $arr[3] = round((@DeskTopHeight-$arr[1])/2)
    InitBigCursors($arr[0],$arr[1])
    BackupPointerSpeedAndAccel($mouse)
    DisablePointerSpeedAndAccel()
    DemoSingletonState(true) ; ask it to initialize state
    $ref_hWnd = GUICreate($i18n_demo_wintitle, $arr[0], $arr[1], $arr[2], $arr[3], 0x80000000)
    GUISetBkColor($COLOR_BLACK, $ref_hWnd)
    GUISetIcon($GLOBAL_PROGRAM_ICON_PATH)
    FrameCounterSingleton(False, $ref_hWnd)
    AdlibRegister ( "FrameCounterUpdate" , 1000 )

    GUISetState(@SW_DISABLE, $g_hForm)
    GUISetState(@SW_SHOW, $ref_hWnd)
    GUIRegisterMsg($WM_SETCURSOR,WndProc)
    ToolTip( _
       'Press Esc to quit, click Mouse 2 to toggle crosshair lock.' & @CRLF & _ 
       'Try out the different ways of panning using edge-pushing, mouse1-drag, or mouse3-pan.', _ 
       $arr[2],$arr[3]+$arr[1])
    Return $arr
EndFunc

Func DemoWinddownProcedure(ByRef $ref_hWnd, ByRef $mouse)
     AdlibUnRegister ( "FrameCounterUpdate" )
     FrameCounterSingleton(False, Null)

     ToolTip('')
     GUIDelete($ref_hWnd)
     RestorePointerSpeedAndAccel($mouse)

     GUIRegisterMsg($WM_SETCURSOR,"")
     GUISetState(@SW_ENABLE, $g_hForm)
EndFunc

Func DemoDrawRoutine($front,$back,$info,$state)
     Local Static $hor = DllStructCreate('long x1;long y1;long x2;long y2;')
     Local Static $ver = DllStructCreate('long x1;long y1;long x2;long y2;')
     Local $modunit = $state.gridsize

     BitBlt($back,0,0,$info.width,$info.height,$front,0,0,0x42,$gdi32dll)

     Local $modceil = $modunit*ceiling($info.height/$modunit/2)     ; how many whole grid units needed to cover the window
     $hor.x1=0
     $hor.x2=$info.width-1
     for $i=-$modceil to $modceil step $modunit
         Local $y = $info.height/2+$i - mod($state.y,$modunit)
         $hor.y1=$y
         $hor.y2=$y
         Polyline($back,$hor,2,$gdi32dll)
     next

     Local $modceil = $modunit*ceiling($info.width/$modunit/2)      ; how many whole grid units needed to cover the window
     $ver.y1=0
     $ver.y2=$info.height-1
     for $i=-$modceil to $modceil step $modunit
         Local $x = $info.width/2+$i - mod($state.x,$modunit)
         $ver.x1=$x
         $ver.x2=$x
         Polyline($back,$ver,2,$gdi32dll)
     next

     BitBlt($front,0,0,$info.width,$info.height,$back,0,0,0xCC0020,$gdi32dll)
EndFunc

Func Demo($toggle = null)
     Local Static $hDemoWin, $hDCFront, $hDCBack, $hBitmap
     Local Static $bufferInfo = DllStructCreate('long width;long height;')
     Local Static $mouse=[10, 0, 0, 0] , $renderUnlocked=false
     Local Static $submodebackup=3
     Local Static $demoState = DemoSingletonState()
     if $toggle then ; this must be checked before the render case, because $renderunlocked is stateful
        if $renderUnlocked then ; end the demo
           $renderUnlocked = false ; do this first in case main loop calls
           _FreeCursor()
           ReleaseDC($hDemoWin,$hDCFront)
           DeleteObject($hBitmap)
           DeleteDC($hDCBack)
           DemoWinddownProcedure($hDemoWin, $mouse )
           SetDeviceSubscriptionMode($submodebackup)
        else                    ; start the demo
           $submodebackup = GetDeviceSubscriptionMode()
           SetDeviceSubscriptionMode(3+BitAND(4,$submodebackup))

           Local $arr = DemoStartupProcedure( $hDemoWin, $mouse )
           $bufferInfo.width=$arr[0]
           $bufferInfo.height=$arr[1]

           Local $hDCScreen = GetDC(Null)
           $hDCFront = GetDC($hDemoWin)
           $hDCBack = CreateCompatibleDC($hDCScreen)
           $hBitmap = CreateCompatibleBitmap($hDCScreen,$bufferInfo.width,$bufferInfo.height)
           SelectObject($hDCBack,$hBitmap)
           SelectObject($hDCBack,GetStockObject(19))
           SetDCPenColor($hDCBack,0x00808080)

           $demoState.dpi = GetDpiForWindow($hDemoWin, $user32dll)
           $demoState.left = $arr[2]
           $demoState.top = $arr[3]
           $demoState.right = $arr[0]+$arr[2]
           $demoState.bottom = $arr[1]+$arr[3]
           _LockCursor(Int($arr[2]+$arr[0]/2),Int($arr[3]+$arr[1]/2),$user32dll)
           GUISetCursor(16,1,$hDemoWin)
           SetCursor($hLimeCursor, $user32dll)
           $renderUnlocked = true ; do this last
        endif
     elseif $renderUnlocked and $toggle=null then ; called from main loop. Note that we only run on main loop calls, otherwise the processing gets clogged
           DemoDrawRoutine($hDCFront,$hDCBack,$bufferInfo,$demoState)
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

; this function is only run once, subsequent calls will just exit
Func InitBigCursors($hor,$ver)
#cs
     Global $hWhiteCursor = _LoadBigCursor(@ScriptDir & "\assets\cursors\white.cur")
     Global $hLimeCursor = _LoadBigCursor(@ScriptDir & "\assets\cursors\lime.cur")
     Global $hCyanCursor  = _LoadBigCursor(@ScriptDir & "\assets\cursors\cyan.cur")
     Global $hYellowCursor = _LoadBigCursor(@ScriptDir & "\assets\cursors\yellow.cur")
#ce
     Local Static $alreadyRun = False 
     If $alreadyRun Then Return
     $alreadyRun = True
     Local $gdi32 = DllOpen('gdi32.dll'),$user32=DllOpen('user32.dll')
     Local $hDC = DllCall($user32,'handle','GetDC','handle',Null)[0]
     Local $tag = 'dword[' & $hor*$ver & '];'
     Local $rawColor = [ _
           DllStructCreate($tag) , _
           DllStructCreate($tag) , _
           DllStructCreate($tag) , _
           DllStructCreate($tag) ]
     Local $column=1+Int($hor/2)
     For $row=1 to $ver
          Local $n = ($row-1)*$hor+$column
          DllStructSetData($rawColor[0], 1, 0xff00ff00, $n)
          DllStructSetData($rawColor[1], 1, 0xffffff00, $n)
          DllStructSetData($rawColor[2], 1, 0xff00ffff, $n)
          DllStructSetData($rawColor[3], 1, 0xffffffff, $n)
     Next
     Local $row=1+Int($ver/2)
     For $column=1 to $hor
          Local $n = ($row-1)*$hor+$column
          DllStructSetData($rawColor[0], 1, 0xff00ff00, $n)
          DllStructSetData($rawColor[1], 1, 0xffffff00, $n)
          DllStructSetData($rawColor[2], 1, 0xff00ffff, $n)
          DllStructSetData($rawColor[3], 1, 0xffffffff, $n)
     Next
     Local $hbmColor = [ _
           DllCall($gdi32,'handle','CreateBitmap','int',$hor,'int',$ver,'uint',1,'uint',32,'struct*',$rawColor[0])[0] , _
           DllCall($gdi32,'handle','CreateBitmap','int',$hor,'int',$ver,'uint',1,'uint',32,'struct*',$rawColor[1])[0] , _
           DllCall($gdi32,'handle','CreateBitmap','int',$hor,'int',$ver,'uint',1,'uint',32,'struct*',$rawColor[2])[0] , _
           DllCall($gdi32,'handle','CreateBitmap','int',$hor,'int',$ver,'uint',1,'uint',32,'struct*',$rawColor[3])[0] ]
     Local $hbmMask  = Dllcall($gdi32,'handle','CreateCompatibleBitmap','handle',$hDC, 'int',$hor,'int',$ver)[0]
     Local $hCursor = [ _ 
           CreateIconIndirect(False,int($hor/2),int($ver/2),$hbmMask,$hbmColor[0],$user32) , _
           CreateIconIndirect(False,int($hor/2),int($ver/2),$hbmMask,$hbmColor[1],$user32) , _
           CreateIconIndirect(False,int($hor/2),int($ver/2),$hbmMask,$hbmColor[2],$user32) , _
           CreateIconIndirect(False,int($hor/2),int($ver/2),$hbmMask,$hbmColor[3],$user32) ]
     DllCall($gdi32,'bool','DeleteObject','handle',$hbmMask)
     DllCall($gdi32,'bool','DeleteObject','handle',$hbmColor[0])
     DllCall($gdi32,'bool','DeleteObject','handle',$hbmColor[1])
     DllCall($gdi32,'bool','DeleteObject','handle',$hbmColor[2])
     DllCall($gdi32,'bool','DeleteObject','handle',$hbmColor[3])
     DllClose($gdi32)
     DllClose($user32)
     Global $hLimeCursor   = $hCursor[0]
     Global $hYellowCursor = $hCursor[1]
     Global $hCyanCursor   = $hCursor[2]
     Global $hWhiteCursor  = $hCursor[3]
     OnAutoItExitRegister(CleanupCursors)
EndFunc

Func CleanupCursors()
     DestroyCursor($hWhiteCursor)
     DestroyCursor($hLimeCursor)
     DestroyCursor($hCyanCursor)
     DestroyCursor($hYellowCursor)
EndFunc
