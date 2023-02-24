; #############################################################################
; ## unRBM                                                                   ##
; ##                                                                         ##
; ## (c) defiler     (defiler@elitereversers.de)                             ##
; ## and ultraschall (ultraschall@elitereversers.de)                         ##
; #############################################################################

.486p
.model flat,stdcall
include include\windows.inc
includelib lib\kernel32.lib
includelib lib\user32.lib
option scoped

.data	; --- DATA ----------------------------

Caption		db	'unRBM (c) by ultraschall and defiler in 2000, all rights reversed.',0
Feedback	db	0Dh,0Ah,'We want feedback! Please email us if you use this little tool!',0Dh,0Ah
		db	'Email: defiler@elitereversers.de and ultraschall@elitereversers.de',0
NotFound	db	'ERROR! File could not be found.',0Dh,0Ah
		db	' Usage: unRBM.exe <.rbm-file>',0Dh,0Ah,0
Working		db	'Working...',0
FMapError	db	'ERROR! Could not create file mapping.',0Dh,0Ah,0
FMapViewError	db	'ERROR! Could not map view of file.',0Dh,0Ah,0
NoConsole	db	'ERROR! Console could not be initialized.',0Dh,0Ah,0
RBMCorrupt	db	'ERROR! .rbm file is corrupt.',0Dh,0Ah,0
Success		db	0Dh,0Ah,'.rbm file successfully repacked.',0Dh,0Ah,0
InsertCD	db	'Rb32ful.dat in current directory not found. Please insert your Rebirth 2.0 CD.',0Dh,0Ah,0
Watermark	db	'KRACHMACHERHURE'
WMCounter	dd	0
FileIndex	dd	0

ChkSum_Val1	dd	02000h		; initial values!
ChkSum_Val2	dd	03000h

.data?	; --- BSS -----------------------------

hFile		dd	?
hMap		dd	?
lpData		dd	?
FileSize	dd	?
hConsole	dd	?
hDatFile	dd	?
GayBytes	dd	?
ResetOfs	dd	?
ResetPos	dd	?
TmpFName	db	50h dup(?)
Drives		db	100h dup(?)
CSumBuffer	db	400h dup(?)
KeyBuffer1	db	800h dup(?)
KeyBuffer2	db	800h dup(?)

.const	; --- RDATA ---------------------------

EMBF_SIG	db	'EMBF'
INFO_SIG	db	'INFO'
COMMENTS	db	'COMMENTS.TXT',0
FTP		db	'FTP.TXT',0
WWW		db	'WWW.TXT',0
MODNAME		db	'MODNAME.TXT',0
CRLF		db	0Dh,0Ah,0
DatFile		db	'Rb20ful.dat',0

.code	; --- CODE ----------------------------

; Return: 	eax = File offset
CheckSumToOfs PROC ChkSum: DWORD
		push	ecx
		push	edx
		mov	eax,ChkSum
		xor	edx,edx
		mov	ecx,07FFF800h
		div	ecx
		xchg	edx,eax
		add	eax,0100h
		pop	edx
		pop	ecx
		ret
CheckSumToOfs ENDP

StrLen PROC lpText: DWORD
		push	ecx
		push	edi
		push	esi
		xor	eax,eax
		or	ecx,-1
		mov	edi,lpText	;edi=lpText
		mov	esi,edi		;esi=lpText
		repne	scasb
		not	ecx
		dec	ecx		;ecx=length of Text
		xchg	ecx,eax
		pop	esi
		pop	edi
		pop	ecx
		ret
StrLen ENDP

StrCopy PROC Source: DWORD,Dest: DWORD
		pushad
		mov	esi,Source
		mov	edi,Dest
		invoke	StrLen,esi
		xchg	ecx,eax
		inc	ecx
		cld
		rep	movsb
		popad
		ret
StrCopy ENDP

StrCat PROC StrOfs1: DWORD, StrOfs2: DWORD
		pushad
		mov	esi,StrOfs1
		mov	edi,StrOfs2
		invoke	StrLen,edi
		add	edi,eax
		invoke	StrLen,esi
		xchg	ecx,eax
		inc	ecx
		cld
		rep	movsb
		popad
		ret
StrCat ENDP

TextOut PROC lpText: DWORD
		pushad			;save all regs
		
		invoke	StrLen,lpText
		mov	esi,lpText

		;###    write text to console + #13,#10

		invoke  WriteFile,hConsole,esi,eax,addr GayBytes,0
		invoke  WriteFile,hConsole,offset CRLF,2,addr GayBytes,0
		
		popad
		ret
TextOut ENDP

MoveMem PROC Source,Dest,BufSize: DWORD
		pushad
		cld
		mov	ecx,BufSize
		mov	esi,Source
		mov	edi,Dest
		rep	movsb
		popad
		ret
MoveMem ENDP

RealCalc PROC Limit: DWORD
		xor	edx,edx

CalcLoop:
		mov	eax,[ebx+ecx]
		bswap	eax
		
		add	edx,eax
		add	ecx,4
		cmp	ecx,Limit
		jb	CalcLoop
		ret
RealCalc ENDP

CalculateChecksum PROC Buffer: DWORD,_Size: DWORD
		pushad
		
		cld
		mov	ecx,0400h
		mov	al,'e'
		mov	edi,offset CSumBuffer
		rep	stosb
		
		cmp	_Size,400h
		jb	SizeOK
		mov	_Size,400h

SizeOK:
		invoke	MoveMem,Buffer,addr CSumBuffer,_Size
		
		mov	ebx,offset CSumBuffer
		xor	ecx,ecx
		
		invoke	RealCalc,200h
		add	ChkSum_Val1,edx
		
		invoke	RealCalc,400h
		add	ChkSum_Val2,edx
		
		popad
		ret
CalculateChecksum ENDP

Decrypt PROC Buffer: DWORD,_Size: DWORD
		pushad
		
		mov	esi,offset KeyBuffer1
		mov	eax,FileIndex
		cdq
		xor	eax,edx
		sub	eax,edx
		and	eax,1
		xor	eax,edx
		sub	eax,edx
		test	eax,eax
		jz	KB1
		mov	esi,offset KeyBuffer2

KB1:
		mov	ResetOfs,esi
	
		mov	eax,FileIndex
		imul	eax,eax,11h
		cdq
		mov	ecx,785h
		idiv	ecx
		add	edx,7Bh	
		mov	ResetPos,edx
		
		mov	eax,Buffer
		mov	ecx,_Size
		xor	edx,edx
		
LoopDecryption:
		mov	bl,byte ptr [eax]
		add	bl,byte ptr [esi]
		mov	byte ptr [eax],bl
		inc	eax
		inc	esi
		inc	edx

		cmp	edx,ResetPos
		jnz	DontReset
		
		mov	esi,ResetOfs
		xor	edx,edx
		
DontReset:		
		loop	LoopDecryption

DQuit:	
		popad
		ret
Decrypt ENDP

; Round = 0 --> Calculate Checksum
; Round = 1 --> Decrypt
; Round = 2 --> Watermark

Traverse PROC Round: DWORD
		;###    
		;###    traverse the directory
		;###    

		mov	ebx,lpData
		xor	edx,edx

TraverseLoop:
		mov	eax,ebx
		add	eax,edx
		
		;###    check if entry is aligned
		
		push	edx
		xor	edx,edx
		mov	ecx,2
		div	ecx
		test	edx,edx
		pop	edx
		jz	IsAligned

		cmp	Round,2
		jnz	NoWatermark
		
		cmp	WMCounter,15
		jge	Align

		mov	eax,offset Watermark
		add	eax,WMCounter
		mov	cl,byte ptr [eax]
		mov	byte ptr [ebx+edx+114h],cl
		inc	WMCounter

NoWatermark:
Align:
		inc	edx
		
IsAligned:
		mov	eax,dword ptr [ebx+edx+114h]

		;###    is it an info record?
		
		cmp	eax,dword ptr [INFO_SIG]
		jnz	IsNotInfo
		mov	eax,dword ptr [ebx+edx+118h]
		bswap	eax
		jmp	SkipNextCheck
		
IsNotInfo:
		;###    is it a file?

		cmp	eax,dword ptr [EMBF_SIG]
		stc
		jnz	Quit
		mov	eax,dword ptr [ebx+edx+118h]
		bswap	eax

		;###    print filename
				
		mov	ecx,ebx
		add	ecx,edx
		add	ecx,11Ch

		cmp	Round,0
		jnz	Round1

		;###    calculate checksum
		invoke	CalculateChecksum,ecx,eax
		jmp	CCDone
		
Round1:
		cmp	Round,1
		jnz	SkipDecrypt
		
		inc	dword ptr FileIndex
		cmp	eax,0400h
		jbe	SkipDecrypt
		sub	eax,0400h
		add	ecx,0400h
		invoke	Decrypt,ecx,eax
		
SkipDecrypt:		
		mov	eax,dword ptr [ebx+edx+118h]
		bswap	eax
		
CCDone:	
SkipNextCheck:
		add	edx,eax
		add	edx,8
		cmp	edx,FileSize
		jb	TraverseLoop

		clc

Quit:		
		ret
Traverse ENDP		

main:

		;###    init console

		invoke	GetStdHandle,STD_OUTPUT_HANDLE
		cmp	eax,INVALID_HANDLE_VALUE
		jz	errNoConsole
		mov	hConsole,eax

		;###    display progname and stuff

		invoke	TextOut,addr CRLF
		invoke	TextOut,addr Caption
		invoke	TextOut,addr Feedback
		invoke	TextOut,addr CRLF
		invoke	Sleep,3000

		;###    get commandline + parametres
		
		invoke	GetCommandLineA
		mov	edi,eax
		
		cmp	byte ptr [eax],'"'
		jnz	NoSpace
		mov	eax,'"'
		inc	edi
		or	ecx,-1
		repne	scasb
		inc	edi
		jmp	Scanned
		
NoSpace:
		mov	eax,020h
		or	ecx,-1
		repne	scasb
		
Scanned:
		;###    try to open .rbm file provided by commandline

		invoke	CreateFileA,edi,GENERIC_READ or GENERIC_WRITE,0,0,OPEN_EXISTING,0,0
		cmp	eax,0FFFFFFFFh
		jz	errFileNotFound
		mov     hFile,eax

		;###    get filesize
		
		invoke	GetFileSize,eax,0
		cmp	eax,114h
		jb	errFileCorrupt
		sub	eax,114h
		mov	FileSize,eax

		;###    create filemapping

		invoke	CreateFileMappingA,hFile,0,PAGE_READWRITE,0,0,0
		test	eax,eax
		jz	errFileMapping
		mov	hMap,eax

		;###    map file into memory

		invoke	MapViewOfFile,eax,FILE_MAP_WRITE,0,0,0
		test	eax,eax
		jz	errMapView
		mov	lpData,eax

		invoke	TextOut,addr Working

		;###    attempt to open .dat file in current directory

		invoke	CreateFileA,addr DatFile,GENERIC_READ,0,0,OPEN_EXISTING,0,0
		cmp	eax,INVALID_HANDLE_VALUE
		jnz	InCurDir

		;###    find cd drive and try to open .dat file

		invoke	GetLogicalDriveStringsA,100h,addr Drives
		xor	ecx,ecx

NextDrive:
		mov	ebx,offset Drives
		add	ebx,ecx
		cmp	byte ptr [ebx],0	; all drives checked?
		jz	errNoRBCD		; if yes, quit
		add	ecx,4
		
		push	ecx
		invoke	GetDriveTypeA,ebx
		pop	ecx
		cmp	eax,5			; is CDROM?
		jnz	NextDrive		

		;###	build filename: "X:\Rb20ful.dat"
		
		mov	eax,offset Drives
		add	eax,ecx
		sub	eax,4
		invoke	StrCopy,eax,addr TmpFName
		invoke	StrCat,addr DatFile,addr TmpFName

		;###	attempt to open the file

		push	ecx
		invoke	CreateFileA,addr TmpFName,GENERIC_READ,0,0,OPEN_EXISTING,0,0
		pop	ecx
		cmp	eax,INVALID_HANDLE_VALUE
		jz	NextDrive		; if openerror then next drive

InCurDir:
		mov	hDatFile,eax

		invoke	Traverse,0
		jc	errFileCorrupt
		
		invoke	CheckSumToOfs,ChkSum_Val1
		invoke	SetFilePointer,hDatFile,eax,0,FILE_BEGIN
		invoke	ReadFile,hDatFile,addr KeyBuffer1,800h,addr GayBytes,0
		
		invoke	CheckSumToOfs,ChkSum_Val2
		invoke	SetFilePointer,hDatFile,eax,0,FILE_BEGIN
		invoke	ReadFile,hDatFile,addr KeyBuffer2,800h,addr GayBytes,0
		
		invoke	CloseHandle,hDatFile

		invoke	Traverse,1
		invoke	Traverse,2

		;###	deinitialize and quit

		invoke	TextOut,addr Success
		
Quit4:		
		invoke	UnmapViewOfFile,lpData
		
Quit3:
		invoke	CloseHandle,hMap
		
Quit2:
		invoke	CloseHandle,hFile
		
Quit:
		invoke	ExitProcess,0
		

errNoConsole:
		invoke	MessageBoxA,0,addr NoConsole,addr Caption,0
		jmp	Quit

errFileNotFound:
		invoke	TextOut,addr NotFound
		jmp	Quit

errFileMapping:
		invoke	TextOut,addr FMapError
		jmp	Quit2

errMapView:
		invoke	TextOut,addr FMapViewError
		jmp	Quit3

errFileCorrupt:
		invoke	TextOut,addr RBMCorrupt
		jmp	Quit4

errNoRBCD:
		invoke	TextOut,addr InsertCD
		jmp	Quit4		

end main