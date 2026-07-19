; util.asm - strings, growable vectors, dictionaries, file IO
;
; Growable arrays (StrList, Dictionaries, and the selects/ranges/JSON vectors
; used elsewhere) all share the same 24-byte "vec" layout: items ptr / len /
; cap (see VEC_* in macros.inc). vec_push() is the single generic grow+append
; routine; everything else is built on top of it.

%include "macros.inc"

section .text

extern malloc
extern realloc
extern free
extern memcpy
extern strlen
extern strcmp
extern strcat
extern fopen
extern fclose
extern fseek
extern ftell
extern fread

global wl_strdup
global wl_strndup
global rtrim_inplace
global read_file
global vec_push
global strlist_init
global strlist_free
global strlist_push
global strlist_push_owned
global strlist_join
global dictionaries_init
global dictionaries_free
global dictionaries_set
global dictionaries_get
global dictionaries_has

; ---------------------------------------------------------------- wl_strdup
wl_strdup:
    PROLOG
    push rbx
    push r12
    mov rbx, rdi
    test rbx, rbx
    jz .null
    mov rdi, rbx
    call strlen
    mov r12, rax
    lea rdi, [r12 + 1]
    call malloc
    test rax, rax
    jz .out
    mov rdi, rax
    mov rsi, rbx
    lea rdx, [r12 + 1]
    call memcpy
    jmp .out
.null:
    xor eax, eax
.out:
    pop r12
    pop rbx
    EPILOG

; -------------------------------------------------------------- wl_strndup
wl_strndup:
    PROLOG
    push rbx
    push r12
    mov rbx, rdi
    mov r12, rsi
    test rbx, rbx
    jz .null
    lea rdi, [r12 + 1]
    call malloc
    test rax, rax
    jz .out
    mov rdi, rax
    mov rsi, rbx
    mov rdx, r12
    call memcpy
    mov byte [rax + r12], 0
    jmp .out
.null:
    xor eax, eax
.out:
    pop r12
    pop rbx
    EPILOG

; ----------------------------------------------------------- rtrim_inplace
rtrim_inplace:
    PROLOG
    push rbx
    push r12
    mov rbx, rdi
    test rbx, rbx
    jz .out
    mov rdi, rbx
    call strlen
    mov rcx, rax
.loop:
    test rcx, rcx
    jz .out
    movzx eax, byte [rbx + rcx - 1]
    cmp al, 0x20
    je .is_space
    cmp al, 0x09
    jb .out
    cmp al, 0x0d
    ja .out
.is_space:
    dec rcx
    mov byte [rbx + rcx], 0
    jmp .loop
.out:
    pop r12
    pop rbx
    EPILOG

; ---------------------------------------------------------------- read_file
read_file:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    mov r14, rdi
    mov rdi, r14
    lea rsi, [rel mode_rb_str]
    call fopen
    test rax, rax
    jz .fail0
    mov rbx, rax
    mov rdi, rbx
    xor esi, esi
    mov edx, 2
    call fseek
    test eax, eax
    jnz .fail_close
    mov rdi, rbx
    call ftell
    test rax, rax
    js .fail_close
    mov r12, rax
    mov rdi, rbx
    xor esi, esi
    xor edx, edx
    call fseek
    test eax, eax
    jnz .fail_close
    lea rdi, [r12 + 1]
    call malloc
    test rax, rax
    jz .fail_close
    mov r13, rax
    mov rdi, r13
    mov rsi, 1
    mov rdx, r12
    mov rcx, rbx
    call fread
    mov r12, rax
    mov rdi, rbx
    call fclose
    mov byte [r13 + r12], 0
    mov rax, r13
    jmp .out
.fail_close:
    mov rdi, rbx
    call fclose
.fail0:
    xor eax, eax
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; --------------------------------------------------------------- vec_push
; vec_push(vec*, data*, elem_size) -> eax 0 ok, -1 fail
vec_push:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov rax, [r12 + VEC_LEN]
    cmp rax, [r12 + VEC_CAP]
    jne .have_room
    mov rbx, [r12 + VEC_CAP]
    test rbx, rbx
    jnz .dbl
    mov rbx, 8
    jmp .doreal
.dbl:
    imul rbx, rbx, 2
.doreal:
    mov rdi, [r12 + VEC_ITEMS]
    mov rsi, rbx
    imul rsi, r14
    call realloc
    test rax, rax
    jz .fail
    mov [r12 + VEC_ITEMS], rax
    mov [r12 + VEC_CAP], rbx
.have_room:
    mov rax, [r12 + VEC_LEN]
    imul rax, r14
    add rax, [r12 + VEC_ITEMS]
    mov rdi, rax
    mov rsi, r13
    mov rdx, r14
    call memcpy
    inc qword [r12 + VEC_LEN]
    xor eax, eax
    jmp .out
.fail:
    mov eax, -1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------------------------- strlist_*
strlist_init:
    mov qword [rdi + VEC_ITEMS], 0
    mov qword [rdi + VEC_LEN], 0
    mov qword [rdi + VEC_CAP], 0
    ret

strlist_free:
    PROLOG
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .clear
    xor rbx, rbx
.loop:
    cmp rbx, [r12 + VEC_LEN]
    jae .free_arr
    mov rax, [r12 + VEC_ITEMS]
    mov rdi, [rax + rbx*8]
    call free
    inc rbx
    jmp .loop
.free_arr:
    mov rdi, [r12 + VEC_ITEMS]
    call free
.clear:
    mov qword [r12 + VEC_ITEMS], 0
    mov qword [r12 + VEC_LEN], 0
    mov qword [r12 + VEC_CAP], 0
.out:
    pop r12
    pop rbx
    EPILOG

; strlist_push_owned(list*, s*) -> eax 0/-1, consumes s always
strlist_push_owned:
    PROLOG
    push rbx
    push r12
    mov r12, rdi
    mov rbx, rsi
    sub rsp, 16
    mov [rsp], rbx
    mov rdi, r12
    mov rsi, rsp
    mov rdx, 8
    call vec_push
    add rsp, 16
    test eax, eax
    js .fail
    xor eax, eax
    jmp .out
.fail:
    mov rdi, rbx
    call free
    mov eax, -1
.out:
    pop r12
    pop rbx
    EPILOG

; strlist_push(list*, s_const*) -> eax 0/-1
strlist_push:
    PROLOG
    push rbx
    push r12
    mov r12, rdi
    mov rbx, rsi
    mov rdi, rbx
    call wl_strdup
    test rax, rax
    jz .fail
    mov rdi, r12
    mov rsi, rax
    call strlist_push_owned
    jmp .out
.fail:
    mov eax, -1
.out:
    pop r12
    pop rbx
    EPILOG

; strlist_join(list*, sep*) -> rax malloc'd string (may be NULL on OOM)
strlist_join:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    xor r14, r14
    test r13, r13
    jz .no_sep_len
    mov rdi, r13
    call strlen
    mov r14, rax
.no_sep_len:
    mov r15, 1
    xor rbx, rbx
.count_loop:
    cmp rbx, [r12 + VEC_LEN]
    jae .count_done
    mov rax, [r12 + VEC_ITEMS]
    mov rdi, [rax + rbx*8]
    call strlen
    add r15, rax
    mov rax, rbx
    inc rax
    cmp rax, [r12 + VEC_LEN]
    jae .no_add_sep
    add r15, r14
.no_add_sep:
    inc rbx
    jmp .count_loop
.count_done:
    mov rdi, r15
    call malloc
    test rax, rax
    jz .fail
    mov r15, rax
    mov byte [r15], 0
    xor rbx, rbx
.join_loop:
    cmp rbx, [r12 + VEC_LEN]
    jae .done
    mov rdi, r15
    mov rax, [r12 + VEC_ITEMS]
    mov rsi, [rax + rbx*8]
    call strcat
    test r13, r13
    jz .no_sep_cat
    mov rax, rbx
    inc rax
    cmp rax, [r12 + VEC_LEN]
    jae .no_sep_cat
    mov rdi, r15
    mov rsi, r13
    call strcat
.no_sep_cat:
    inc rbx
    jmp .join_loop
.done:
    mov rax, r15
    jmp .out
.fail:
    xor eax, eax
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ---------------------------------------------------------- dictionaries_*
dictionaries_init:
    mov qword [rdi + VEC_ITEMS], 0
    mov qword [rdi + VEC_LEN], 0
    mov qword [rdi + VEC_CAP], 0
    ret

dictionaries_free:
    PROLOG
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .clear
    xor rbx, rbx
.loop:
    cmp rbx, [r12 + VEC_LEN]
    jae .free_arr
    mov rax, [r12 + VEC_ITEMS]
    imul rcx, rbx, DICTENTRY_SIZE
    add rax, rcx
    mov rdi, [rax + DICTENTRY_NAME]
    call free
    mov rax, [r12 + VEC_ITEMS]
    imul rcx, rbx, DICTENTRY_SIZE
    add rax, rcx
    lea rdi, [rax + DICTENTRY_WORDS]
    call strlist_free
    inc rbx
    jmp .loop
.free_arr:
    mov rdi, [r12 + VEC_ITEMS]
    call free
.clear:
    mov qword [r12 + VEC_ITEMS], 0
    mov qword [r12 + VEC_LEN], 0
    mov qword [r12 + VEC_CAP], 0
.out:
    pop r12
    pop rbx
    EPILOG

; dictionaries_set(dicts*, name*, words*) -> eax 0/-1; always consumes words
dictionaries_set:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 32
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    xor rbx, rbx
.search_loop:
    cmp rbx, [r12 + VEC_LEN]
    jae .not_found
    mov rax, [r12 + VEC_ITEMS]
    imul rcx, rbx, DICTENTRY_SIZE
    add rax, rcx
    mov rdi, [rax + DICTENTRY_NAME]
    mov rsi, r13
    call strcmp
    test eax, eax
    jnz .search_next
    mov rax, [r12 + VEC_ITEMS]
    imul rcx, rbx, DICTENTRY_SIZE
    add rax, rcx
    lea rdi, [rax + DICTENTRY_WORDS]
    call strlist_free
    mov rax, [r12 + VEC_ITEMS]
    imul rcx, rbx, DICTENTRY_SIZE
    add rax, rcx
    lea rdi, [rax + DICTENTRY_WORDS]
    mov rsi, [r14 + 0]
    mov [rdi + 0], rsi
    mov rsi, [r14 + 8]
    mov [rdi + 8], rsi
    mov rsi, [r14 + 16]
    mov [rdi + 16], rsi
    xor eax, eax
    jmp .out
.search_next:
    inc rbx
    jmp .search_loop
.not_found:
    mov rdi, r13
    call wl_strdup
    test rax, rax
    jz .fail_words
    mov [rsp + 0], rax
    mov rax, [r14 + 0]
    mov [rsp + 8], rax
    mov rax, [r14 + 8]
    mov [rsp + 16], rax
    mov rax, [r14 + 16]
    mov [rsp + 24], rax
    mov rdi, r12
    mov rsi, rsp
    mov rdx, DICTENTRY_SIZE
    call vec_push
    test eax, eax
    js .fail_name_words
    xor eax, eax
    jmp .out
.fail_name_words:
    mov rdi, [rsp + 0]
    call free
    mov rdi, r14
    call strlist_free
    mov eax, -1
    jmp .out
.fail_words:
    mov rdi, r14
    call strlist_free
    mov eax, -1
.out:
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; dictionaries_get(dicts*, name*) -> rax = StrList* or NULL
dictionaries_get:
    PROLOG
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    xor rbx, rbx
.loop:
    cmp rbx, [r12 + VEC_LEN]
    jae .null
    mov rax, [r12 + VEC_ITEMS]
    imul rcx, rbx, DICTENTRY_SIZE
    add rax, rcx
    mov rdi, [rax + DICTENTRY_NAME]
    mov rsi, r13
    push rax
    call strcmp
    pop rcx
    test eax, eax
    jnz .next
    lea rax, [rcx + DICTENTRY_WORDS]
    jmp .out
.next:
    inc rbx
    jmp .loop
.null:
    xor eax, eax
.out:
    pop r13
    pop r12
    pop rbx
    EPILOG

; dictionaries_has(dicts*, name*) -> eax 0/1
dictionaries_has:
    PROLOG
    call dictionaries_get
    test rax, rax
    setnz al
    movzx eax, al
    EPILOG

section .note.GNU-stack noexec

section .rodata
mode_rb_str: db "rb", 0
