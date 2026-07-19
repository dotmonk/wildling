; generator.asm - a Generator wraps one parsed pattern's TokenList and knows
; how many combinations it can produce / how to render the Nth one.

%include "macros.inc"

section .text

extern free
extern wl_strdup
extern strlist_init
extern strlist_free
extern strlist_push_owned
extern strlist_join
extern parse_pattern
extern tokenlist_free
extern token_count
extern token_get

global generator_init
global generator_free
global generator_count
global generator_get

; generator_init(gen*, input_pattern*, dictionaries*) -> eax 0/-1
generator_init:
    PROLOG
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov rdi, r12
    call wl_strdup
    test rax, rax
    jz .fail0
    mov [rbx + GENERATOR_SOURCE], rax
    mov rdi, r12
    mov rsi, r13
    lea rdx, [rbx + GENERATOR_TOKENS]
    call parse_pattern
    test eax, eax
    jz .count
    mov rdi, [rbx + GENERATOR_SOURCE]
    call free
    mov qword [rbx + GENERATOR_SOURCE], 0
    jmp .fail0
.count:
    mov r12d, 1
    xor r13, r13
.count_loop:
    cmp r13, [rbx + GENERATOR_TOKENS + TOKENLIST_LEN]
    jae .count_done
    mov rax, [rbx + GENERATOR_TOKENS + TOKENLIST_ITEMS]
    imul rcx, r13, TOKEN_SIZE
    add rax, rcx
    mov rdi, rax
    call token_count
    imul r12d, eax
    inc r13
    jmp .count_loop
.count_done:
    mov dword [rbx + GENERATOR_COUNT], r12d
    xor eax, eax
    jmp .out
.fail0:
    mov eax, -1
.out:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    EPILOG

; generator_free(gen*)
generator_free:
    PROLOG
    push rbx
    sub rsp, 8
    mov rbx, rdi
    mov rdi, [rbx + GENERATOR_SOURCE]
    call free
    lea rdi, [rbx + GENERATOR_TOKENS]
    call tokenlist_free
    mov qword [rbx + GENERATOR_SOURCE], 0
    add rsp, 8
    pop rbx
    EPILOG

; generator_count(gen*) -> eax
generator_count:
    mov eax, dword [rdi + GENERATOR_COUNT]
    ret

; generator_get(gen*, index:int32) -> rax malloc'd string (caller frees)
generator_get:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 32
    mov rbx, rdi
    movsxd r12, esi
    mov eax, dword [rbx + GENERATOR_COUNT]
    dec eax
    cmp r12d, eax
    jg .empty
    test r12d, r12d
    js .empty

    mov rdi, rsp
    call strlist_init
    xor r13, r13
.loop:
    cmp r13, [rbx + GENERATOR_TOKENS + TOKENLIST_LEN]
    jae .join
    mov rax, [rbx + GENERATOR_TOKENS + TOKENLIST_ITEMS]
    imul rcx, r13, TOKEN_SIZE
    add rax, rcx
    mov r14, rax
    mov rdi, r14
    call token_count
    mov ecx, eax
    mov eax, r12d
    xor edx, edx
    div ecx
    mov r12d, eax
    mov rdi, r14
    mov esi, edx
    call token_get
    test rax, rax
    jz .fail
    mov rdi, rsp
    mov rsi, rax
    call strlist_push_owned
    test eax, eax
    js .fail2
    inc r13
    jmp .loop
.join:
    lea rdi, [rsp]
    lea rsi, [rel empty_str2]
    call strlist_join
    mov rbx, rax
    mov rdi, rsp
    call strlist_free
    mov rax, rbx
    jmp .out
.fail:
    mov rdi, rsp
    call strlist_free
    xor eax, eax
    jmp .out
.fail2:
    mov rdi, rsp
    call strlist_free
    xor eax, eax
    jmp .out
.empty:
    lea rdi, [rel empty_str2]
    call wl_strdup
.out:
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

section .note.GNU-stack noexec

section .rodata
empty_str2: db 0
