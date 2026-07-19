; token.asm - token expansion (fixed alphabet / dictionary / word-list pieces)

%include "macros.inc"

section .text

extern malloc
extern realloc
extern free
extern strlen
extern memcpy
extern wl_strdup
extern strlist_init
extern strlist_free

global token_options_init
global token_options_free
global token_init
global token_free
global token_count
global token_get

; token_options_init(opts*)
token_options_init:
    mov qword [rdi + TOKENOPTS_STRING], 0
    mov dword [rdi + TOKENOPTS_START_LEN], 1
    mov dword [rdi + TOKENOPTS_END_LEN], 1
    mov dword [rdi + TOKENOPTS_HAS_START], 0
    mov dword [rdi + TOKENOPTS_HAS_END], 0
    mov qword [rdi + TOKENOPTS_SRC], 0
    lea rdi, [rdi + TOKENOPTS_VARIANTS]
    call strlist_init
    ret

; token_options_free(opts*)
token_options_free:
    PROLOG
    push rbx
    push r12
    mov r12, rdi
    mov rdi, [r12 + TOKENOPTS_STRING]
    call free
    mov rdi, [r12 + TOKENOPTS_SRC]
    call free
    lea rdi, [r12 + TOKENOPTS_VARIANTS]
    call strlist_free
    mov qword [r12 + TOKENOPTS_STRING], 0
    mov qword [r12 + TOKENOPTS_SRC], 0
    pop r12
    pop rbx
    EPILOG

; pow_int(base, exp) -- rdi=base(32) rsi=exp(32) -> eax
; Leaf helper: touches only eax/ecx/edi/esi, safe to call around any
; callee-saved register state.
pow_int:
    mov eax, 1
    mov ecx, esi
.loop:
    test ecx, ecx
    jle .out
    imul eax, edi
    dec ecx
    jmp .loop
.out:
    ret

; token_init(token*, opts*) -> eax 0/-1
; On success takes ownership of opts->src / opts->variants (opts is left
; zeroed for those fields); opts->string is always freed.
token_init:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov r14, qword [r13 + TOKENOPTS_SRC]
    test r14, r14
    jnz .have_src
    lea rdi, [rel empty_str]
    call wl_strdup
    mov r14, rax
.have_src:
    test r14, r14
    jz .fail
    mov [r12 + TOKEN_SRC], r14
    mov qword [r13 + TOKENOPTS_SRC], 0

    mov eax, dword [r13 + TOKENOPTS_HAS_START]
    test eax, eax
    jz .default_start
    mov eax, dword [r13 + TOKENOPTS_START_LEN]
    test eax, eax
    js .default_start
    jmp .store_start
.default_start:
    mov eax, 1
.store_start:
    mov dword [r12 + TOKEN_START_LEN], eax

    mov eax, dword [r13 + TOKENOPTS_HAS_END]
    test eax, eax
    jz .default_end
    mov eax, dword [r13 + TOKENOPTS_END_LEN]
    test eax, eax
    js .default_end
    jmp .store_end
.default_end:
    mov eax, 1
.store_end:
    mov dword [r12 + TOKEN_END_LEN], eax

    mov rax, [r13 + TOKENOPTS_VARIANTS + VEC_ITEMS]
    mov [r12 + TOKEN_VARIANTS + VEC_ITEMS], rax
    mov rax, [r13 + TOKENOPTS_VARIANTS + VEC_LEN]
    mov [r12 + TOKEN_VARIANTS + VEC_LEN], rax
    mov rax, [r13 + TOKENOPTS_VARIANTS + VEC_CAP]
    mov [r12 + TOKEN_VARIANTS + VEC_CAP], rax
    mov qword [r13 + TOKENOPTS_VARIANTS + VEC_ITEMS], 0
    mov qword [r13 + TOKENOPTS_VARIANTS + VEC_LEN], 0
    mov qword [r13 + TOKENOPTS_VARIANTS + VEC_CAP], 0

    mov ebx, dword [r12 + TOKEN_VARIANTS + VEC_LEN]
    xor r14d, r14d
    mov r15d, dword [r12 + TOKEN_START_LEN]
.count_loop:
    cmp r15d, dword [r12 + TOKEN_END_LEN]
    jg .count_done
    mov edi, ebx
    mov esi, r15d
    call pow_int
    add r14d, eax
    inc r15d
    jmp .count_loop
.count_done:
    mov dword [r12 + TOKEN_COUNT], r14d

    mov rdi, [r13 + TOKENOPTS_STRING]
    call free
    mov qword [r13 + TOKENOPTS_STRING], 0
    xor eax, eax
    jmp .out
.fail:
    mov eax, -1
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; token_free(token*)
token_free:
    PROLOG
    push rbx
    push r12
    mov r12, rdi
    mov rdi, [r12 + TOKEN_SRC]
    call free
    lea rdi, [r12 + TOKEN_VARIANTS]
    call strlist_free
    mov qword [r12 + TOKEN_SRC], 0
    pop r12
    pop rbx
    EPILOG

; token_count(token*) -> eax
token_count:
    mov eax, dword [rdi + TOKEN_COUNT]
    ret

; token_get(token*, index) -> rax malloc'd string (caller frees), never NULL
; unless out of memory. rdi=token*, esi=index (signed int).
;
; Locals (24 bytes on the stack): [rsp+0]=cur_len [rsp+8]=vlen [rsp+16]=variant*
token_get:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov r12, rdi
    movsxd r13, esi

    mov eax, dword [r12 + TOKEN_COUNT]
    dec eax
    cmp r13d, eax
    jg .empty
    test r13d, r13d
    js .empty

    mov eax, dword [r12 + TOKEN_START_LEN]
    test r13d, r13d
    jnz .skip_zero_check
    test eax, eax
    jz .empty
.skip_zero_check:

    mov r14d, dword [r12 + TOKEN_VARIANTS + VEC_LEN]
    mov r15d, dword [r12 + TOKEN_END_LEN]
    mov ebx, dword [r12 + TOKEN_START_LEN]
.len_loop:
    cmp ebx, r15d
    jg .empty
    mov edi, r14d
    mov esi, ebx
    call pow_int
    cmp r13d, eax
    jl .found_len
    sub r13d, eax
    inc ebx
    jmp .len_loop
.found_len:
    ; ebx = string_length, r13d = index_with_offset, r14d = variants_len
    mov r15, [r12 + TOKEN_VARIANTS + VEC_ITEMS]
    mov rdi, 1
    call malloc
    test rax, rax
    jz .fail
    mov byte [rax], 0
    mov r12, rax
    mov qword [rsp + 0], 0
.build_loop:
    test ebx, ebx
    jz .done
    mov eax, r13d
    xor edx, edx
    div r14d
    mov r13d, eax
    mov rax, [r15 + rdx*8]
    mov [rsp + 16], rax
    mov rdi, rax
    call strlen
    mov [rsp + 8], rax
    mov rcx, [rsp + 0]
    lea rsi, [rcx + rax + 1]
    mov rdi, r12
    call realloc
    test rax, rax
    jz .fail_mid
    mov r12, rax
    mov rdi, r12
    add rdi, [rsp + 0]
    mov rsi, [rsp + 16]
    mov rdx, [rsp + 8]
    inc rdx
    call memcpy
    mov rax, [rsp + 0]
    add rax, [rsp + 8]
    mov [rsp + 0], rax
    dec ebx
    jmp .build_loop
.done:
    mov rax, r12
    jmp .out
.fail_mid:
    mov rdi, r12
    call free
    jmp .fail
.empty:
    lea rdi, [rel empty_str]
    call wl_strdup
    jmp .out
.fail:
    xor eax, eax
.out:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

section .note.GNU-stack noexec

section .rodata
empty_str: db 0
