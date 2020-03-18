; vim: ft=fasm tabstop=8 shiftwidth=8:

format ELF64 executable 3

include 'unistd_64.inc'

TFORTH_VERSION = 1
RETURN_STACK_SIZE = 8192
BUFFER_SIZE = 4096

F_IMMED = 0x80
F_HIDDEN = 0x20
F_LENMASK = 0x1f
link = 0

macro NEXT {
	lodsq
	jmp qword [rax]
}

macro PUSHRSP reg {
	lea rbp, [rbp-8]	; push reg onto the return stack
	mov [rbp], reg
}

macro POPRSP reg {
	mov reg, [rbp]		; pop top of return stack to reg
	lea rbp, [rbp+8]
}


macro defword name*, namelen*, label*, flags=0 {
	;; segment readable
	align 8
name_#label:
	dq link
	db namelen + flags
	db name

	link = name_#label

	align 8
w_#label:
	dq DOCOL
}

macro defcode name*, namelen*, label*, flags=0 {
	;; segment readable
	align 8
name_#label:
	dq link
	db namelen + flags
	db name

	link = name_#label

	align 8
c_#label:
	dq code_#label

	;; segment readable executable
	align 8
code_#label:
}

macro defvar name*, namelen*, label*, flags=0, initial=0 {
	defcode name, namelen, label, flags
	push var_#label
	NEXT

	segment readable writeable
	align 8
var_#label:
	dq initial
}

macro defconst name*, namelen*, label*, flags=0, value=0 {
	defcode name, namelen, label, flags
	push value
	NEXT
}

segment readable executable

DOCOL:
	PUSHRSP rsi
	add rax, 8
	mov rsi, rax
	NEXT

entry $
	cld
	mov [var_S0], rsp
	mov rbp, return_stack_top
	call set_up_data_segment

	mov rsi, cold_start
	NEXT

cold_start:
	dq w_QUIT

	defcode "DROP",4,DROP			; drop top of stack
	pop rax
	NEXT

	defcode "SWAP",4,SWAP			; swap top two elements on stack
	pop rax
	pop rbx
	push rax
	push rbx
	NEXT

	defcode "DUP",3,DUP			; duplicate top of stack
	mov rax,[rsp+8]
	push rax
	NEXT

	defcode "OVER",4,OVER
	mov rax, [rsp+8]			; get the second element of stack
	push rax				; push it on top
	NEXT

	defcode "ROT",3,ROT
	pop rax
	pop rbx
	pop rcx
	push rbx
	push rax
	push rcx
	NEXT

	defcode "-ROT",4,NROT
	pop rax
	pop rbx
	pop rcx
	push rax
	push rcx
	push rbx
	NEXT

	defcode "2DROP",5,TWODROP		; drop top two elements of stack
	pop rax
	pop rax
	NEXT

	defcode "2DUP",4,TWODUP			; duplicate top two elements
	mov rax,[rsp]
	mov rbx,[rsp+8]
	push rbx
	push rax
	NEXT

	defcode "2SWAP",5,TWOSWAP		; swap top two pairs of elements
	pop rax
	pop rbx
	pop rcx
	pop rdx
	push rbx
	push rax
	push rdx
	push rcx
	NEXT

	defcode "?DUP",4,QDUP			; duplicate top of stack of non-zero
	mov rax, [rsp]
	test rax, rax
	jz .next
	push rax
.next:	NEXT

	defcode "1+",2,INCR			; increment top of stack
	inc qword [rsp]
	NEXT

	defcode "1-",2,DECR			; decrement top of stack
	dec qword [rsp]
	NEXT

	defcode "8+",2,INCR8			; add 8 to top of stack
	add qword [rsp], 8
	NEXT

	defcode "8-",2,DECR8			; substrack 8 to top of stack
	sub qword [rsp], 8
	NEXT

	defcode "+",1,ADD
	pop rax					; get top of stack
	add [rsp], rax				; and add it to next word on stack
	NEXT

	defcode "-",1,SUB
	pop rax					; get top of stack
	sub [rsp], rax				; and substract it from next work on stack
	NEXT

	defcode "*",1,MUL
	pop rax
	pop rbx
	imul rax, rbx
	push rax				; ignore overflow
	NEXT

	defcode "/MOD",4,DIVMOD
	xor rdx, rdx
	pop rbx
	pop rax
	idiv rbx
	push rdx				; push remainder
	push rax				; push quotient
	NEXT

macro defcmp name*, namelen*, label*, cond* {
	defcode name, namelen, label
	pop rax
	pop rbx
	cmp rbx, rax
	set#cond al
	movzx rax, al
	push rax
	NEXT
}

	defcmp "=",	1,	EQU,	e
	defcmp "<>",	2,	NEQ,	ne
	defcmp "<",	1,	LT,	l
	defcmp ">",	1,	GT,	g
	defcmp "<=",	2,	LE,	le
	defcmp ">=",	2,	GE,	ge

macro deftest name*, namelen*, label*, cond* {
	defcode name, namelen, label
	pop rax
	test rax, rax
	set#cond al
	movzx rax, al
	push rax
	NEXT
}

	deftest "0=",	2,	ZEQU,	z
	deftest "0<>",	3,	ZNEQU,	nz
	deftest "0<",	2,	ZLT,	l
	deftest "0>",	2,	ZGT,	g
	deftest "0<=",	3,	ZLE,	le
	deftest "0>=",	3,	ZGE,	ge

	defcode "AND", 3, AND			; bitwise AND
	pop rax
	and [rsp], rax
	NEXT

	defcode "OR", 2, OR			; bitwise OR
	pop rax
	or [rsp], rax
	NEXT

	defcode "XOR", 3, XOR			; bitwise XOR
	pop rax
	xor [rsp], rax
	NEXT

	defcode "INVERT", 6, INVERT		; Forth bitwise "NOT" (NEGATE and NOTE)
	not qword [rsp]
	NEXT

	defcode "EXIT", 4, EXIT
	POPRSP rsi				; pop return stack into rsi
	NEXT

	defcode "LIT", 3, LIT
	lodsq
	push rax				; push the literal number onto the stack
	NEXT

	defcode "!", 1, STORE
	pop rbx					; address to store at
	pop rax					; data to store
	mov [rbx], rax				; store it
	NEXT

	defcode "@", 1, FETCH
	pop rbx					; address to fetch
	mov rax, [rbx]				; fetch it
	push rax				; push value onto stack
	NEXT

	defcode "+!", 2, ADDSTORE
	pop rbx					; address
	pop rax					; the amount to add
	add [rbx], rax				; add it
	NEXT

	defcode "-!", 2, SUBSTORE
	pop rbx					; address
	pop rax					; the amount to subtract
	sub [rbx], rax				; substract it
	NEXT

	defcode "C!", 2, STOREBYTE
	pop rbx					; address to store at
	pop rax					; data to store there
	mov [rbx], al				; store it
	NEXT

	defcode "C@", 2, FETCHBYTE
	pop rbx					; address to fetch
	xor rax, rax
	mov al, [rbx]				; fetch it
	push rax				; push value onto stack
	NEXT

	defcode "C@C!", 4, CCOPY
	mov rbx, [rsp+8]			; source address
	mov al, [rbx]				; get source character
	pop rdi					; destination address
	stosb					; copy to destination
	push rdi				; increment destination address
	inc qword [rsp+8]			; increment source address
	NEXT

	defcode "CMOVE", 5, CMOVE
	mov rdx, rsi				; preserve rsi
	pop rcx					; length
	pop rdi					; destination address
	pop rsi					; source address
	rep movsb				; copy source to destination
	mov rsi, rdx				; restore rsi

	defconst "VERSION",	7,	VERSION,	,	TFORTH_VERSION
	defconst "R0",		2,	RZ,		,	return_stack_top
	defconst "DOCOL",	5,	__DOCOL,	,	DOCOL
	defconst "F_IMMED",	7,	__F_IMMED,	,	F_IMMED
	defconst "F_HIDDEN",	8,	__F_HIDDEN,	,	F_HIDDEN
	defconst "F_LENMASK",	9,	__F_LENMASK,	,	F_LENMASK

	defconst "SYS_EXIT",	8,	SYS_EXIT,	,	__NR_exit
	defconst "SYS_OPEN",	8,	SYS_OPEN,	,	__NR_open
	defconst "SYS_CLOSE",	9,	SYS_CLOSE,	,	__NR_close
	defconst "SYS_READ",	8,	SYS_READ,	,	__NR_read
	defconst "SYS_WRITE",	9,	SYS_WRITE,	,	__NR_write
	defconst "SYS_CREAT",	9,	SYS_CREAT,	,	__NR_creat
	defconst "SYS_BRK",	7,	SYS_BRK,	,	__NR_brk
	
	defconst "O_RDONLY",	8,	__O_RDONLY,	,	0
	defconst "O_WRONLY",	8,	__O_WRONLY,	,	1
	defconst "O_RDWR",	6,	__O_RDWR,	,	2
	defconst "O_CREAT",	7,	__O_CREAT,	,	0100
	defconst "O_EXCL",	6,	__O_EXCL,	,	0200
	defconst "O_TRUNC",	7,	__O_TRUNC,	,	01000
	defconst "O_APPEND",	8,	__O_APPEND,	,	02000
	defconst "O_NONBLOCK", 	10,	__O_NONBLOCK,	,	04000

	defcode ">R", 2, TOR
	pop rax					; pop parameter stack into rax
	PUSHRSP rax				; push it onto the return stack
	NEXT

	defcode "R>", 2, FROMR
	POPRSP rax				; pop return stack onto rax
	push rax				; push onto parameter stack
	NEXT

	defcode "RSP@", 4, RSPFETCH
	push rbp
	NEXT

	defcode "RSP!", 4, RSPSTORE
	pop rbp
	NEXT

	defcode "RDROP", 5, RDROP
	add rbp, 8				; pop return stack and throw away
	NEXT

	defcode "DSP@", 4, DSPFETCH
	mov rax, rsp
	push rax
	NEXT

	defcode "DSP!", 4, DSPSTORE
	pop rsp
	NEXT

	defcode "KEY", 3, KEY
	call _KEY
	push rax
	NEXT

_KEY:
	mov rbx, [currkey]
	cmp rbx, [bufftop]
	jge .buffull				; exhausted the input buffer?
	xor rax, rax
	mov al, [rbx]				; get next key from input buffer
	inc rbx
	mov [currkey], rbx			; increment currkey
	ret

.buffull:
	push rsi				; save rsi temporarily
	push rdi				; and rdi
	xor rdi, rdi				; stdin
	mov rsi, buffer				; pointer to the buffer
	mov [currkey], rsi
	mov rdx, BUFFER_SIZE			; how many bytes to read max
	mov rax, __NR_read			; read(0, buffer, size)
	syscall

	test rax, rax
	jbe .eof
	add rsi, rax
	mov [bufftop], rsi
	pop rdi					; restore
	pop rsi					; and restore
	jmp _KEY

.eof:
	xor rdi, rdi
	mov rax, __NR_exit
	syscall

	defcode "EMIT", 4, EMIT
	pop rax
	call _EMIT
	NEXT

_EMIT:
	mov rdi, 1				; stdout
	mov [emit_scratch], al			; save the byte to scratch buffer
	push rsi				; save rsi temporarily
	mov rsi, emit_scratch
	mov rdx, 1				; nbytes
	mov rax, __NR_write			; write(1, scratch, 1)
	syscall
	pop rsi					; restore it
	ret

_WORD:
.ws:
	call _KEY				; get next key, returned in rax
	cmp al, '\'				; start of comment?
	je .comment				; if so, skip the comment
	cmp al, ' '
	jbe .ws					; if so, keep looking

	mov rdi, word_buffer
.word:
	stosb					; add character to return buffer
	call _KEY				; get next key, returned in al
	cmp al, ' '				; is blank?
	ja .word				; if no, keep looping

	sub rdi, word_buffer
	mov rcx, rdi				; return length of the word
	mov rdi, word_buffer			; return address of the word
	ret

.comment:
	call _KEY
	cmp al, 0x0A				; end of line?
	jne .comment
	jmp .ws

_NUMBER:
	xor rax, rax
	xor rbx, rbx

	test rcx, rcx				; zero-length string, return 0
	jz .ret

	mov rdx, [var_BASE]			; get BASE

	; check if first character is '-'
	mov bl, [rdi]				; bl = first character
	inc rdi
	push rax				; push 0 on stack
	cmp bl, '-'				; negative number?
	jnz .convert
	pop rax
	push rbx				; push <> 0 on stack, indicating negative
	dec rcx
	jnz .loop
	pop rbx					; error: string is only '-'
	mov rcx, 1
	ret

.loop:
	imul rax, rdx				; rax *= BASE
	mov bl, [rdi]				; bl = next character
	inc rdi

.convert:
	sub bl, '0'				; < '0' ?
	jb .finish
	cmp bl, 10				; <= '9' ?
	jb .numeric
	sub bl, 17				; < 'A' (17 is 'A'-'0')
	jb .finish
	add bl, 10

.numeric:
	cmp bl, dl				; >= BASE
	jge .finish

	add rax, rbx
	dec rcx
	jnz .loop

	; negate the result if first character was '-'
.finish:
	pop rbx
	test rbx, rbx
	jz .ret
	neg rax

.ret:
	ret

	defcode "FIND", 4, FIND
	pop rcx					; rcx = length
	pop rdi					; rdi = address
	call _FIND
	push rax				; rax = address of dictionary entry
	NEXT

_FIND:
	push rsi				; save rsi so we can use it in comparisons

	; sart searching backwards through the dictionary list
	mov rdx, var_LATEST			; LATEST points to name header

.loop:
	test rdx, rdx				; NULL pointer?
	je .notfound

	; compare length expected and current word
	; if F_HIDDEN or F_LENMASK is set, don't pick the word
	xor rax, rax
	mov al, [rdx+8]				; al = flags+length field
	and al, F_HIDDEN or F_LENMASK		; al = name length
	cmp al, cl				; length is the same
	jne .next

	; compare the strings in detail
	push rcx				; save the length
	push rdi				; save the address
	lea rsi, [rdx+9]			; dictionary string
	repe cmpsb				; compare the strings
	pop rdi
	pop rcx
	jne .next				; not the same

	; strings are the same!
	pop rsi
	mov rax, rdx
	ret

.next:
	mov rdx, [rdx]				; move back through the link field
	jmp .loop				; ... and loop

.notfound:
	pop rsi
	xor rax, rax				; return zero to indicate not found
	ret

	defcode ">CFA", 4, TCFA
	pop rdi
	call _TCFA
	push rdi
	NEXT

_TCFA:
	xor eax, eax
	add rdi, 8				; skip link pointer
	mov al, [rdi]				; load flags+len into al
	inc rdi					; skip flags+len byte
	and al, F_LENMASK			; just the length, not the flags
	add rdi, rax				; skip the name
	add rdi, 7				; the codeword is 8-byte aligned
	and rdi, not 7
	ret

	defword ">DFA", 4, TDFA
	dq c_TCFA
	dq c_INCR8
	dq c_EXIT

	defcode "CREATE", 6, CREATE
	pop rcx					; rcx = length
	pop rbx					; rbx = address of name

	mov rdi, [var_HERE]			; rdi is the address of the header
	mov rax, [var_LATEST]			; get link pointer
	stosq					; store it in the header

	mov cl, al				; get the length
	stosb					; store the length/flags byte
	push rsi
	mov rsi, rbx				; rsi = word
	rep movsb				; copy the word
	pop rsi
	add rdi, 7				; align to next 8-byte boundary.
	and rdi, not 7

	; update LATEST and HERE
	mov rax, [var_HERE]
	mov [var_LATEST], rax
	mov [var_HERE], rdi
	NEXT

	defcode ",", 1, COMMA
	pop rax					; code pointer to store
	call _COMMA
	NEXT

_COMMA:
	mov rdi, [var_HERE]			; HERE
	stosq					; store it
	mov [var_HERE], rdi			; update HERE (incremented)
	ret

	defcode "[", 1, LBRAC, F_IMMED
	xor rax, rax
	mov [var_STATE], rax			; Set STATE to 0
	NEXT

	defcode "]", 1, RBRAC
	mov qword [var_STATE], 1		; Set STATE to 1
	NEXT

	defword ":", 1, COLON
	dq c_WORD				; get the name of the new word
	dq c_CREATE				; CREATE the dictionary entry
	dq c_LIT, DOCOL, c_COMMA		; Append DOCOL
	dq c_LATEST, c_FETCH, c_HIDDEN		; make the word hidden
	dq c_RBRAC				; go into compile mode
	dq c_EXIT				; return from the function

	defword ";", 1, SEMICOLON, F_IMMED
	dq c_LIT, c_EXIT, c_COMMA		; append EXIT
	dq c_LATEST, c_FETCH, c_HIDDEN		; toggle hidden flag (unhide the word)
	dq c_LBRAC				; go back to immediate mode
	dq c_EXIT				; return from the function

	defword "IMMEDIATE", 9, IMMEDIATE, F_IMMED
	mov rdi, [var_LATEST]			; LATEST word
	add rdi, 8				; point to name/flags byte
	xor byte [rdi], F_IMMED			; toggle the F_IMMED flag
	NEXT

	defcode "HIDDEN", 6, HIDDEN
	pop rdi					; dictionary entry
	add rdi, 8				; point to name/flags byte
	xor byte [rdi], F_HIDDEN		; toggle the F_HIDDEN flag
	NEXT

	defword "HIDE", 4, HIDE
	dq c_WORD				; get the next word
	dq c_FIND				; look up in the dictionary
	dq c_HIDDEN				; set F_HIDDEN flag
	dq c_EXIT				; return

	defcode "'", 1, TICK
	lodsq					; get the address of the next word
	push rax				; push it on the stack
	NEXT

	defcode "BRANCH", 6, BRANCH
	add rsi, [rsi]				; add the offset to the instruction pointer
	NEXT

	defcode "0BRANCH", 7, ZBRANCH
	pop rax
	test rax, rax				; top of stack is zero?
	jz code_BRANCH				; if so, jump to the branch function above
	lodsq					; otherwise, skip the offset
	NEXT

	defcode "LITSTRING", 9, LITSTRING
	lodsq					; get length of the string
	push rsi				; push the address of the start
	push rax				; push it on the stack
	add rsi, rax				; skip past the string
	add rsi, 7				; round up to next 8-byte boundary
	and rsi, not 7
	NEXT

	defcode "TELL", 4, TELL
	mov rcx, rsi				; save temporarily
	mov rdi, 1				; 1st param = stdout
	pop rdx					; 3nd param = length
	pop rsi					; 2nd param = string
	mov rax, __NR_write
	push rcx
	syscall
	pop rsi					; restore rsi
	NEXT

	; QUIT MUST NOT RETURN (DO NOT CALL EXIT)
	defword "QUIT", 4, QUIT
	dq c_RZ, c_RSPSTORE			; R0 RSP! clear the return stack
	dq c_INTERPRET				; interpret the next word
	dq c_BRANCH, -16			; and loop

	defcode "INTERPRET", 9, INTERPRET
	call _WORD				; return rcx = length, rdi = pointer

	xor rax, rax
	mov [interpret_is_lit], rax		; not a literal number
	call _FIND				; returns rax = pointer to header
	test rax, rax				; found?
	jz .number

	mov rdi, rax
	mov al, [rdi+8]				; rdi = dictionary entry
	push ax					; get name+flags
	call _TCFA				; convert dictionary entry to codeword
	pop ax
	and al, F_IMMED				; is F_IMMED set?
	mov rax, rdi
	jnz .exec				; if F_IMMED, jump to executing

	jmp .main

.number:
	inc qword [interpret_is_lit]
	call _NUMBER				; return parsed number
	test rcx, rcx
	jnz .numerror
	mov rbx, rax
	mov rax, c_LIT				; the word is LIT

.main:
	mov rdx, [var_STATE]
	test rdx, rdx
	jz .exec				; jump if executing

	call _COMMA
	mov rcx, [interpret_is_lit]		; was it a literal?
	test rcx, rcx
	jz .next
	mov rax, rbx				; yes, so followed by a number
	call _COMMA

.next:
	NEXT

.exec:
	mov rcx, [interpret_is_lit]		; literal?
	test rcx, rcx
	jnz .litexec

	jmp qword [rax]				; execute the non-literal

.litexec:
	push rbx				; push literal onto stack
	NEXT

.numerror:
	push rsi				; save rsi

	mov rdi, 2				; 1st param: stderr
	mov rsi, errmsg				; 2nd param: error message
	mov rdx, errmsglen			; 3rd param: length
	mov rax, __NR_write
	syscall

	mov rsi, [currkey]			; the error occurred right before here
	mov rdx, rsi
	sub rdx, buffer				; rdx = currkey - buffer
	cmp rdx, buffer				; if > 40, print only 40
	cmp rdx, 40
	jle .le
	mov rdx, 40

.le:
	sub rsi, rdx				; rcx = start of area to print
	mov rax, __NR_write
	syscall

	mov rsi, errmsgnl			; newline
	mov rdx, 1
	mov rax, __NR_write
	syscall
	pop rsi

	NEXT

	;; segment readable
	errmsg: db "PARSE ERROR: "
	errmsglen = $ - errmsg
	errmsgnl: db 0x0A

	defcode "CHAR", 4, CHAR
	call _WORD				; returns rcx = length rdi = pointer
	xor rax, rax
	mov al, [rdi]				; get the first character
	push rax				; push it onto the stack
	NEXT

	defcode "EXECUTE", 7, EXECUTE
	pop rax					; get xt into rax
	jmp qword [rax]				; jump to it

	defcode "SYSCALL3", 8, SYSCALL3
	mov rcx, rsi				; save rsi
	pop rax					
	pop rdi
	pop rsi
	pop rdx
	push rcx				; save rsi
	syscall
	pop rsi					; restore
	push rax
	NEXT

	defcode "SYSCALL2", 8, SYSCALL2
	mov rcx, rsi
	pop rax
	pop rdi
	pop rsi
	push rcx
	syscall
	pop rsi
	push rax
	NEXT

	defcode "SYSCALL1", 8, SYSCALL1
	pop rax
	pop rdi
	syscall
	push rax
	NEXT

	defcode "SYSCALL0", 8, SYSCALL0
	pop rax
	syscall
	push RAX
	NEXT

segment readable executable
set_up_data_segment:
	xor rdi, rdi
	mov rax, __NR_brk
	syscall
	
	mov [var_HERE], rax
	add rax, 65536
	mov rdi, rax
	mov rax, __NR_brk
	syscall
	ret

defvar "STATE", 5, STATE
defvar "HERE", 4, HERE
defvar "LATEST", 6, LATEST,, name_SYSCALL0
defvar "S0", 2, S0
defvar "BASE", 4, BASE, 0, 10


segment readable writeable
	align 8
currkey:
	dq buffer				; current place in input buffer
bufftop:
	dq buffer				; last valid data in input buffer + 1

emit_scratch:
	db 0

	defcode "WORD", 4, WORD
	call _WORD
	push rdi				; push base address
	push rcx				; push length
	NEXT

word_buffer:
	rd 32

	defcode "NUMBER", 6, NUMBER
	pop rcx
	pop rdi
	call _NUMBER
	push rax
	push rcx
	NEXT

	align 8
interpret_is_lit:
	dq 0

return_stack:
	rd 8196
return_stack_top:

	rd 4096
buffer:
	rd BUFFER_SIZE
