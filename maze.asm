	.486					; create 32 bit code
	.model flat, stdcall	; 32 bit memory model
	option casemap:none		; case sensitive

; Include files
	include windows.inc
	include gdi32.inc
	include user32.inc
	include kernel32.inc
	include winmm.inc

; Library files
	includelib gdi32.lib
	includelib user32.lib
	includelib kernel32.lib
	includelib winmm.lib

; Local prototypes
WinMain					proto
WndProc					proto hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD

InitDoubleBuffer		proto
DestroyDoubleBuffer		proto

LoadBMP					proto dwBitmapID:DWORD
DestroyBMP				proto hBitmapDC:DWORD, hBitmap:DWORD

; game console
GameMain				proto
GameInit				proto
GameShutdown			proto
GameUpdate				proto
GameDraw				proto

ProcKeyEvents			proto
GetMapElement			proto dwPosX:DWORD, dwPosY:DWORD
SetMapElement			proto dwPosX:DWORD, dwPosY:DWORD, dwElem:DWORD
UpdateGameSize			proto
CalcBlockSize			proto
NextKey					proto

fillBitmap				proto hBrush:DWORD
DrawTitle				proto
DrawEndMsg				proto
DrawMaze				proto
DrawDoors				proto
DrawKey					proto dwPosX:DWORD, dwPosY:DWORD, dwID:DWORD
DrawHero				proto dwPosX:DWORD, dwPosY:DWORD

; Structures

	.const
; resources
IDS_TITLE               equ	100
IDI_MAZE                equ	101
IDI_SMALL               equ	102
IDB_HERO                equ	103
IDB_KEY	                equ	104
IDB_DOOR                equ	105

; window size
WINDOW_WIDTH			equ	640
WINDOW_HEIGHT			equ	480

; game related
GAME_MAP_SIZE			equ	9
GAME_BORDER_LENGTH		equ 20

GAME_HERO_WIDTH			equ	100
GAME_HERO_HEIGHT		equ 100

GAME_KEY_WIDTH			equ	100
GAME_KEY_HEIGHT			equ 50

GAME_DOOR_WIDTH			equ	100
GAME_DOOR_HEIGHT		equ 100

; game states
GAME_STATE_MENU			equ	0
GAME_STATE_START		equ	1
GAME_STATE_RUN          equ	2
GAME_STATE_WIN          equ	3
GAME_STATE_SHUTDOWN     equ	4
GAME_STATE_EXIT         equ	5

	.data
szClassName				db	'MainClass', 0
szAppName				db	'Maze', 0
szBgmName				db	'bgm.wav', 0
szPrompt				db	'Press ENTER to start', 0
szEndMsg				db	'You Win!', 0
szWrongKey				db	'You do not have the right key', 0

align 4
; maze map 9x9 [0: void 1: soild]
mazeMap					db 11h,01h,00h,00h,00h,00h,00h,00h,14h
						db 00h,01h,00h,01h,00h,01h,01h,01h,01h
						db 00h,01h,00h,01h,00h,01h,00h,00h,00h
						db 00h,01h,00h,01h,00h,01h,00h,01h,00h
						db 00h,00h,00h,01h,00h,01h,00h,01h,00h
						db 00h,01h,00h,01h,10h,01h,00h,01h,00h
						db 00h,01h,00h,01h,01h,01h,00h,01h,00h
						db 00h,01h,00h,01h,13h,01h,00h,01h,00h
						db 12h,01h,00h,00h,00h,00h,00h,01h,00h

keyPos					dw 85h
						dw 05h
						dw 41h
						dw 02h
						dw 27h

	.data?
hInstance				dd	?
hWinMain				dd	?

hDC						dd	?
hBackBufferDC			dd	?
hBackBuffer				dd	?

hHeroDC					dd	?
hHero					dd	?

hKeyDC					dd	?
hKey					dd	?

hDoorDC					dd	?
hDoor					dd	?

; szBuffer				db	1024 dup (?)

startTime				dd	?
isResized				db	?

gameState				dd	?

gameWidth				dd	?
gameHeight				dd	?

blockWidth				dd	?
blockHeight				dd	?

playerX					dd	?
playerY					dd	?

keyX					dd	?
keyY					dd	?
keyID					dd	?

isKeyRecovered			db	?
isWrongKey				db	?

lockedDoors				dd	?
recoveredKey			dd	?

	.code
main:
	call WinMain
	invoke ExitProcess, NULL

WinMain proc
	local wndclass:WNDCLASSEX
	local msg:MSG
				
	invoke GetModuleHandle, NULL
	mov hInstance, eax
	invoke RtlZeroMemory, addr wndclass, sizeof wndclass
				
	invoke LoadIcon, hInstance, IDI_MAZE
	mov wndclass.hIcon, eax
	invoke LoadIcon, hInstance, IDI_SMALL
	mov wndclass.hIconSm, eax
	invoke LoadCursor, hInstance, IDC_ARROW
	mov wndclass.hCursor, eax
	
	push hInstance
	pop wndclass.hInstance
	mov wndclass.cbSize, sizeof WNDCLASSEX
	mov wndclass.style, CS_HREDRAW or CS_VREDRAW
	mov wndclass.lpfnWndProc, offset WndProc
	invoke GetStockObject, BLACK_BRUSH
	mov wndclass.hbrBackground, eax
	mov wndclass.lpszClassName, offset szClassName
	
	; register the window class
	invoke RegisterClassEx, addr wndclass
	.if eax == NULL
		ret
	.endif

	; create the window
	invoke CreateWindowEx, WS_EX_WINDOWEDGE or WS_EX_CLIENTEDGE,\
		offset szClassName,\ ; class
		offset szAppName,\ ; title
		WS_OVERLAPPEDWINDOW,\
		100, 100,\ ; initial x,y
		WINDOW_WIDTH, WINDOW_HEIGHT,\ ; intial width, height
		NULL,\ ; handle to parent
		NULL,\ ; handle to menu
		hInstance,\ ; instance
		NULL ; creation parms
	.if eax == NULL
		ret
	.endif
	mov hWinMain, eax

	; invoke ShowCursor, FALSE ; hide mouse

	invoke ShowWindow, hWinMain, SW_SHOWNORMAL
	invoke UpdateWindow, hWinMain

	; perform all game console specific initialization
	invoke GameInit

	.while TRUE
		invoke PeekMessage, addr msg, NULL, 0, 0, PM_REMOVE
		.if eax
			.break .if msg.message == WM_QUIT
			invoke TranslateMessage, addr msg
			invoke DispatchMessage, addr msg
		.else
			; while((GetTickCount() - startTime) < 17)
			invoke GetTickCount
			sub eax, startTime
			.while eax < 17
			.endw

			invoke GameMain
			invoke InvalidateRect, hWinMain, NULL, FALSE
		.endif
	.endw

	; shutdown game and release all resources
	invoke GameShutdown

	; invoke ShowCursor, TRUE ; show mouse

	ret

WinMain endp

WndProc proc uses ebx edi esi hWnd:DWORD, uMsg:DWORD, wParam:DWORD, lParam:DWORD
	local ps:PAINTSTRUCT
				
	mov	eax, uMsg
	.if eax == WM_CREATE
		invoke PlaySound, addr szBgmName, NULL, SND_FILENAME or SND_ASYNC or SND_LOOP
	.elseif eax == WM_SIZE
		mov isResized, 1
	.elseif eax == WM_PAINT
		invoke BeginPaint, hWnd, addr ps
		mov hDC, eax

		mov	eax, ps.rcPaint.right
		sub	eax, ps.rcPaint.left
		mov	ecx, ps.rcPaint.bottom
		sub	ecx, ps.rcPaint.top

		invoke BitBlt, hDC, ps.rcPaint.left, ps.rcPaint.top, eax, ecx,\
			hBackBufferDC, ps.rcPaint.left, ps.rcPaint.top, SRCCOPY
		invoke EndPaint, hWnd, addr ps
	.elseif eax == WM_KEYDOWN
		invoke ProcKeyEvents
	.elseif eax == WM_CLOSE
		invoke DestroyWindow, hWinMain
	.elseif eax == WM_DESTROY
		invoke PostQuitMessage, NULL
	.else
		invoke DefWindowProc, hWnd, uMsg, wParam, lParam
		ret
	.endif		
	xor eax, eax

	ret

WndProc endp

InitDoubleBuffer proc

	invoke GetDC, hWinMain
	mov hDC, eax

	invoke CreateCompatibleDC, hDC
	mov hBackBufferDC, eax

	invoke CreateCompatibleBitmap, hDC, gameWidth, gameHeight
	mov hBackBuffer, eax

	invoke SelectObject, hBackBufferDC, hBackBuffer

	invoke ReleaseDC, hWinMain, hDC

	ret

InitDoubleBuffer endp

DestroyDoubleBuffer proc

	invoke DeleteDC, hBackBufferDC
	invoke DeleteObject, hBackBuffer
	
	ret

DestroyDoubleBuffer endp

LoadBMP proc dwBitmapID:DWORD
	local hBitmapDC:DWORD, hBitmap:DWORD

	invoke GetDC, hWinMain
	mov hDC, eax

	invoke CreateCompatibleDC, hDC
	mov hBitmapDC, eax

	invoke LoadBitmap, hInstance, dwBitmapID
	mov hBitmap, eax

	invoke SelectObject, hBitmapDC, hBitmap

	invoke ReleaseDC, hWinMain, hDC

	mov eax, hBitmapDC
	mov edx, hBitmap

	ret

LoadBMP endp

DestroyBMP proc hBitmapDC:DWORD, hBitmap:DWORD
	
	invoke DeleteDC, hBitmapDC
	invoke DeleteObject, hBitmap
	
	ret

DestroyBMP endp

GameMain proc

	invoke GameUpdate
	invoke GameDraw

	ret
GameMain endp

GameInit proc

	invoke UpdateGameSize
	invoke InitDoubleBuffer

	invoke LoadBMP, IDB_HERO
	mov hHeroDC, eax
	mov hHero, edx

	invoke LoadBMP, IDB_KEY
	mov hKeyDC, eax
	mov hKey, edx

	invoke LoadBMP, IDB_DOOR
	mov hDoorDC, eax
	mov hDoor, edx

	ret

GameInit endp

GameShutdown proc

	invoke DestroyDoubleBuffer

	invoke DestroyBMP, hHeroDC, hHero
	invoke DestroyBMP, hKeyDC, hKey
	invoke DestroyBMP, hDoorDC, hDoor

	ret

GameShutdown endp

GameUpdate proc
	
	pushad

	.if isResized == 1
		invoke UpdateGameSize
		invoke DestroyDoubleBuffer
		invoke InitDoubleBuffer
	.endif

	mov	eax, gameState
	.if eax == GAME_STATE_MENU
		invoke GetAsyncKeyState, VK_RETURN
		test ah, ah
		.if SIGN?
			mov gameState, GAME_STATE_START
		.endif
	.elseif eax == GAME_STATE_START
		invoke CalcBlockSize

		mov lockedDoors, 5

		mov keyX, 5
		mov keyY, 8
		mov eax, keyID
		or al, 20h
		invoke SetMapElement, keyX, keyY, eax

		mov playerX, 8
		mov playerY, 8

		mov gameState, GAME_STATE_RUN
	.elseif eax == GAME_STATE_RUN
		.if isResized == 1
			invoke CalcBlockSize
		.endif

		; if there is a key in the current player position
		invoke GetMapElement, playerX, playerY 
		mov ebx, eax
		shr bl, 4
		.if bl == 1
			and eax, 0Fh
			.if eax == recoveredKey
				invoke SetMapElement, playerX, playerY, 0
			
				invoke NextKey
				or al, 20h
				invoke SetMapElement, keyX, keyY, eax

				mov isKeyRecovered, 0
				mov isWrongKey, 0
				dec lockedDoors
			.else
				mov isWrongKey, 1
			.endif
		.elseif bl == 2
			and eax, 0Fh
			mov recoveredKey, eax
			invoke SetMapElement, playerX, playerY, 0
			mov isKeyRecovered, 1
			mov isWrongKey, 0
		.endif

		.if lockedDoors == 0
			mov gameState, GAME_STATE_WIN
		.endif
	.elseif eax == GAME_STATE_WIN
	.elseif eax == GAME_STATE_SHUTDOWN
		mov gameState, GAME_STATE_EXIT
	.elseif eax == GAME_STATE_EXIT
		invoke SendMessage, hWinMain, WM_CLOSE, NULL, NULL
	.endif

	mov isResized, 0

	popad
	ret

GameUpdate endp

GameDraw proc

	pushad
	push hDC
	mov eax, hBackBufferDC
	mov hDC, eax

	invoke GetStockObject, BLACK_BRUSH
	invoke fillBitmap, eax

	mov	eax, gameState
	.if eax == GAME_STATE_MENU
		invoke GetStockObject, WHITE_BRUSH
		invoke fillBitmap, eax
		invoke DrawTitle
	.elseif eax == GAME_STATE_RUN
		invoke DrawMaze
		invoke DrawHero, playerX, playerY
		invoke DrawDoors
		.if isKeyRecovered == 0
			invoke DrawKey, keyX, keyY, keyID
		.endif

		.if isWrongKey == 1
			invoke TextOut, hDC, 0, 0, addr szWrongKey, 29
		.endif
	.elseif eax == GAME_STATE_WIN
		invoke GetStockObject, WHITE_BRUSH
		invoke fillBitmap, eax
		invoke DrawEndMsg
	.endif

	pop hDC
	popad
	ret

GameDraw endp
	
ProcKeyEvents proc

	invoke GetAsyncKeyState, VK_ESCAPE
	test ah, ah
	js Close
	invoke GetAsyncKeyState, VK_RIGHT
	test ah, ah
	js Right
	invoke GetAsyncKeyState, VK_LEFT
	test ah, ah
	js Left
	invoke GetAsyncKeyState, VK_UP
	test ah, ah
	js Up
	invoke GetAsyncKeyState, VK_DOWN
	test ah, ah
	js Down
	jmp done

Close:
	mov gameState, GAME_STATE_SHUTDOWN
	jmp done
Right:
	.if playerX < GAME_MAP_SIZE - 1
		inc playerX
		invoke GetMapElement, playerX, playerY
		.if eax == 1 
			dec playerX
		.endif
	.endif
	jmp done
Left:
	.if playerX > 0
		dec playerX
		invoke GetMapElement, playerX, playerY
		.if eax == 1
			inc playerX
		.endif
	.endif
	jmp done
Up:
	.if playerY > 0
		dec playerY
		invoke GetMapElement, playerX, playerY
		.if eax == 1
			inc playerY
		.endif
	.endif
	jmp done
Down:
	.if playerY < GAME_MAP_SIZE - 1
		inc playerY
		invoke GetMapElement, playerX, playerY
		.if eax == 1
			dec playerY
		.endif
	.endif
	jmp done
done:
	ret

ProcKeyEvents endp

GetMapElement proc dwPosX:DWORD, dwPosY:DWORD

	mov eax, dwPosY
	mov ebx, GAME_MAP_SIZE
	mul ebx
	add	eax, dwPosX
	mov al, [mazeMap + eax]
	cbw
	movzx eax, ax

	ret

GetMapElement endp

SetMapElement proc dwPosX:DWORD, dwPosY:DWORD, dwElem:DWORD

	mov eax, dwPosY
	mov ebx, GAME_MAP_SIZE
	mul ebx
	add	eax, dwPosX
	mov ebx, dwElem
	mov [mazeMap + eax], bl

	ret

SetMapElement endp

UpdateGameSize proc
	local rect:RECT

	invoke GetClientRect, hWinMain, addr rect

	mov	eax, rect.right
	sub	eax, rect.left
	mov gameWidth, eax

	mov	eax, rect.bottom
	sub	eax, rect.top
	mov gameHeight, eax

	ret

UpdateGameSize endp

CalcBlockSize proc
	
	mov edx, 0
	mov eax, gameWidth
	sub eax, GAME_BORDER_LENGTH * 2
	mov ebx, GAME_MAP_SIZE
	div ebx
	mov blockWidth, eax

	mov edx, 0
	mov eax, gameHeight
	sub eax, GAME_BORDER_LENGTH * 2
	mov ebx, GAME_MAP_SIZE
	div ebx
	mov blockHeight, eax

	ret

CalcBlockSize endp

NextKey proc

	inc keyID
	.if keyID < 5
		mov ebx, keyID
		mov ax, [keyPos + ebx * 2]
		and eax, 0FFh
		mov ebx, eax
		and eax, 0F0h
		shr eax, 4
		mov keyY, eax
		and ebx, 0Fh
		mov keyX, ebx
	.endif
	mov eax, keyID

	ret

NextKey endp

DrawTitle proc
	local rect:RECT

	invoke GetClientRect, hWinMain, addr rect
	invoke DrawText, hDC, addr szAppName, -1,\
		addr rect,\
		DT_SINGLELINE or DT_CENTER or DT_VCENTER

	mov eax, rect.right
	shr eax, 1
	sub eax, 70

	mov ebx, rect.bottom
	shr ebx, 1
	add ebx, 20

	invoke TextOut, hDC, eax, ebx, addr szPrompt, 20

	ret

DrawTitle endp

DrawEndMsg proc
	local rect:RECT

	invoke GetClientRect, hWinMain, addr rect
	invoke DrawText, hDC, addr szEndMsg, -1,\
		addr rect,\
		DT_SINGLELINE or DT_CENTER or DT_VCENTER

	ret

DrawEndMsg endp

fillBitmap proc hBrush:DWORD
	local rect:RECT

	invoke GetClientRect, hWinMain, addr rect
	invoke FillRect, hDC, addr rect, hBrush

	ret

fillBitmap endp

DrawMaze proc
	local i:DWORD, j:DWORD
	local x1:DWORD, x2:DWORD
	local y1:DWORD, y2:DWORD

	invoke GetStockObject, WHITE_PEN
	invoke SelectObject, hDC, eax
	invoke DeleteObject, eax

	invoke GetStockObject, WHITE_BRUSH
	invoke SelectObject, hDC, eax
	invoke DeleteObject, eax
	
	mov i, 0
	.while i < GAME_MAP_SIZE
		mov j, 0
		.while j < GAME_MAP_SIZE
			invoke GetMapElement, j, i
			.if eax == 0
				mov ebx, blockHeight
				mov eax, i
				mul ebx
				add eax, GAME_BORDER_LENGTH
				mov y1, eax
				add eax, ebx
				mov y2, eax

				mov ebx, blockWidth
				mov eax, j
				mul ebx
				add eax, GAME_BORDER_LENGTH
				mov x1, eax
				add eax, ebx
				mov x2, eax

				invoke Rectangle, hDC, x1, y1, x2, y2
			.endif
			inc j
		.endw
		inc i
	.endw

	ret

DrawMaze endp

DrawDoors proc
	local i:DWORD, j:DWORD
	local x:DWORD, y:DWORD
	local id:DWORD

	mov i, 0
	.while i < GAME_MAP_SIZE
		mov j, 0
		.while j < GAME_MAP_SIZE
			invoke GetMapElement, j, i
			mov ebx, eax
			shr bl, 4
			.if bl == 1
				and eax, 0Fh
				mov id, eax

				mov ebx, blockHeight
				mov eax, i
				mul ebx
				add eax, GAME_BORDER_LENGTH
				mov y, eax

				mov ebx, blockWidth
				mov eax, j
				mul ebx
				add eax, GAME_BORDER_LENGTH
				mov x, eax

				mov ebx, GAME_DOOR_WIDTH
				mov eax, id
				mul ebx
				invoke StretchBlt, hDC, x, y, blockWidth, blockHeight,\
					hDoorDC, eax, 0, GAME_DOOR_WIDTH, GAME_DOOR_HEIGHT, MERGECOPY
			.endif
			inc j
		.endw
		inc i
	.endw
	
	ret

DrawDoors endp

DrawKey proc dwPosX:DWORD, dwPosY:DWORD, dwID:DWORD
	local x:DWORD, y:DWORD

	mov ebx, blockHeight
	mov eax, dwPosY
	mul ebx
	add eax, GAME_BORDER_LENGTH
	mov y, eax

	mov ebx, blockWidth
	mov eax, dwPosX
	mul ebx
	add eax, GAME_BORDER_LENGTH
	mov x, eax

	mov ebx, GAME_KEY_WIDTH
	mov eax, dwID
	mul ebx
	invoke StretchBlt, hDC, x, y, blockWidth, blockHeight,\
		hKeyDC, eax, 0, GAME_KEY_WIDTH, GAME_KEY_HEIGHT, MERGECOPY
	
	ret

DrawKey endp

DrawHero proc dwPosX:DWORD, dwPosY:DWORD
	local x:DWORD, y:DWORD

	mov ebx, blockHeight
	mov eax, dwPosY
	mul ebx
	add eax, GAME_BORDER_LENGTH
	mov y, eax

	mov ebx, blockWidth
	mov eax, dwPosX
	mul ebx
	add eax, GAME_BORDER_LENGTH
	mov x, eax

	invoke StretchBlt, hDC, x, y, blockWidth, blockHeight,\
		hHeroDC, 0, 0, GAME_HERO_WIDTH, GAME_HERO_HEIGHT, MERGECOPY

	ret

DrawHero endp

end main

