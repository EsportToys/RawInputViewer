Func RAWINPUT($raw)
     Switch DllStructGetData(RAWINPUTHEADER($raw),'Type')
       Case 0
            Return RAWMOUSE($raw)
       Case 1
            Return RAWKEYBOARD($raw)
       Case 2
            Return RAWHID($raw)
     EndSwitch
EndFunc

Func RAWINPUTHEADER($raw)
     Local Static $tag = 'struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct;'
     Return DllStructCreate( $tag , DllStructGetPtr($raw) )
EndFunc

Func RAWMOUSE($raw)
     Local Static $tag = 'struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct;' & _
       'ushort Flags;ushort Alignment;ushort ButtonFlags;short ButtonData;ulong RawButtons;long LastX;long LastY;ulong ExtraInformation;'
     Return DllStructCreate( $tag , DllStructGetPtr($raw) )
EndFunc

Func RAWKEYBOARD($raw)
     Local Static $tag = 'struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct;' & _
       'ushort MakeCode;ushort Flags;ushort Reserved;ushort VKey;uint Message;ulong ExtraInformation;'
     Return DllStructCreate( $tag , DllStructGetPtr($raw) )
EndFunc

Func RAWHID($raw)
     Local Static $pre = 'struct;dword Type;dword Size;handle hDevice;wparam wParam;endstruct;' & _
       'dword SizeHid;dword Count;'
     Local $ptr = DllStructGetPtr($raw)
     Local $_ = DllStructCreate($pre,$ptr)
     Local $s = DllStructGetData($_,'SizeHid')
     Local $tag = $pre
     For $i=1 to DllStructGetData($_,'Count')
         $tag &= 'byte Input' & $i & '[' & $s & '];'
     Next
     Return DllStructCreate( $tag , $ptr )
EndFunc

Func _RawInputFetchData($lParam, $_dll='user32.dll')
     Local Static $HEADSIZE = DllStructGetSize(DllStructCreate('struct;dword;dword;handle;wparam;endstruct;'))
     Local $size = DllCall($_dll,'uint','GetRawInputData','handle',$lParam,'uint',0x10000003,'struct*',Null,'uint*',Null,'uint',$HEADSIZE)[4]
     Return DllCall ( $_dll, _
                      'uint' , 'GetRawInputData', _
                    'handle' , $lParam, _
                      'uint' , 0x10000003, _
                   'struct*' , DllStructCreate('byte[' & $size & ']'), _
                     'uint*' , $size, _
                      'uint' , $HEADSIZE )[3]
EndFunc

Func _RawInputRegisterDevice($page, $usage, $flags, $target)
     Local Static $TAG = 'ushort;ushort;dword;hwnd',$SIZE = DllStructGetSize(DllStructCreate($TAG))
     Local $struct = DllStructCreate($TAG)
     DllStructSetData($struct, 1, $page)
     DllStructSetData($struct, 2, $usage)
     DllStructSetData($struct, 3, $flags)
     DllStructSetData($struct, 4, $target)
     Return DllCall('user32.dll','bool','RegisterRawInputDevices','struct*',$struct,'uint',1,'uint',$SIZE)[0]
EndFunc