; wildling.asm - top level: an array of Generators covering all patterns,
; with combined indexing (wildling_get) and an iterator (wildling_next).

%include "macros.inc"

section .text

extern calloc
extern free

extern generator_init
extern generator_free
extern generator_count
extern generator_get

global wildling_init
global wildling_free
global wildling_count
global wildling_reset
global wildling_get
global wildling_next
global wildling_generators

; wildling_init(w*, patterns**, pattern_count:size_t, dictionaries*) -> eax 0/-1
wildling_init:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    mov r14, rcx
    mov qword [rbx + WILDLING_GENS], 0
    mov qword [rbx + WILDLING_GENS_LEN], 0
    mov dword [rbx + WILDLING_PATTERN_CNT], 0
    mov dword [rbx + WILDLING_INTERNAL_IDX], 0

    test r13, r13
    jz .ok0

    mov rdi, r13
    mov rsi, GENERATOR_SIZE
    call calloc
    test rax, rax
    jz .fail0
    mov [rbx + WILDLING_GENS], rax
    mov r15, rax

    ; NOTE: the loop index must live in a callee-saved register (or memory);
    ; rcx/rax/rdx/etc. are caller-saved and get clobbered by calls into
    ; generator_init (and transitively into libc).
    mov qword [rsp], 0
.loop:
    mov rax, [rsp]
    cmp rax, r13
    jae .done
    mov rdx, rax
    mov rax, [r12 + rdx*8]
    imul rdx, rdx, GENERATOR_SIZE
    lea rdi, [r15 + rdx]
    mov rsi, rax
    mov rdx, r14
    call generator_init
    test eax, eax
    jns .advance
    xor r12, r12
.undo_loop:
    cmp r12, [rsp]
    jae .undo_done
    imul rdx, r12, GENERATOR_SIZE
    lea rdi, [r15 + rdx]
    call generator_free
    inc r12
    jmp .undo_loop
.undo_done:
    mov rdi, r15
    call free
    mov qword [rbx + WILDLING_GENS], 0
    jmp .fail0
.advance:
    mov rax, [rsp]
    imul rdx, rax, GENERATOR_SIZE
    lea rdi, [r15 + rdx]
    call generator_count
    add dword [rbx + WILDLING_PATTERN_CNT], eax
    inc qword [rbx + WILDLING_GENS_LEN]
    inc qword [rsp]
    jmp .loop
.done:
    xor eax, eax
    jmp .out
.ok0:
    xor eax, eax
    jmp .out
.fail0:
    mov eax, -1
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; wildling_free(w*)
wildling_free:
    PROLOG
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rdi
    test rbx, rbx
    jz .out
    mov r12, [rbx + WILDLING_GENS]
    test r12, r12
    jz .out
    xor r13, r13
.loop:
    cmp r13, [rbx + WILDLING_GENS_LEN]
    jae .free_arr
    imul rax, r13, GENERATOR_SIZE
    lea rdi, [r12 + rax]
    call generator_free
    inc r13
    jmp .loop
.free_arr:
    mov rdi, r12
    call free
    mov qword [rbx + WILDLING_GENS], 0
    mov qword [rbx + WILDLING_GENS_LEN], 0
.out:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    EPILOG

; wildling_count(w*) -> eax
wildling_count:
    mov eax, dword [rdi + WILDLING_PATTERN_CNT]
    ret

; wildling_reset(w*)
wildling_reset:
    mov dword [rdi + WILDLING_INTERNAL_IDX], 0
    ret

; wildling_get(w*, index:int32) -> rax malloc'd string or NULL
wildling_get:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov rbx, rdi
    movsxd r12, esi
    mov eax, dword [rbx + WILDLING_PATTERN_CNT]
    dec eax
    cmp r12d, eax
    jg .null
    test r12d, r12d
    js .null

    xor r13, r13
    xor r14, r14
.loop:
    cmp r14, [rbx + WILDLING_GENS_LEN]
    jae .null
    mov rax, [rbx + WILDLING_GENS]
    imul rcx, r14, GENERATOR_SIZE
    add rax, rcx
    mov r15, rax
    mov rdi, r15
    call generator_count
    mov ecx, r12d
    sub ecx, r13d
    cmp ecx, eax
    jl .found
    add r13d, eax
    inc r14
    jmp .loop
.found:
    mov rdi, r15
    mov esi, ecx
    call generator_get
    jmp .out
.null:
    xor eax, eax
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; wildling_next(w*) -> rax malloc'd string or NULL
wildling_next:
    PROLOG
    mov eax, dword [rdi + WILDLING_INTERNAL_IDX]
    cmp eax, dword [rdi + WILDLING_PATTERN_CNT]
    jne .advance
    xor eax, eax
    jmp .out
.advance:
    mov esi, eax
    inc dword [rdi + WILDLING_INTERNAL_IDX]
    call wildling_get
.out:
    EPILOG

; wildling_generators(w*, out_len*) -> rax Generator* (out_len may be NULL)
wildling_generators:
    test rsi, rsi
    jz .skip
    mov rax, [rdi + WILDLING_GENS_LEN]
    mov [rsi], rax
.skip:
    mov rax, [rdi + WILDLING_GENS]
    ret

section .note.GNU-stack noexec
