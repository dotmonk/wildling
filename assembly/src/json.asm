; json.asm - minimal JSON parser for --template files
;
; JsonValue layout (JSONVAL_*, see macros.inc): type / bool / number(double)
; / string* / array items*+len+cap / object entries*+len+cap.
; Numbers are parsed with libc strtod (glibc, allowed alongside malloc etc).

%include "macros.inc"

section .text

extern malloc
extern realloc
extern calloc
extern free
extern strcmp
extern strncmp
extern strtod
extern vec_push

global json_parse
global json_free
global json_object_get

; ---------------------------------------------------------------- skip_ws
; skip_ws(Parser*) -> advances PARSER_POS past ' ' \n \r \t
skip_ws:
    mov rax, [rdi + JSONPARSER_TEXT]
.loop:
    mov rcx, [rdi + JSONPARSER_POS]
    movzx edx, byte [rax + rcx]
    cmp dl, ' '
    je .adv
    cmp dl, 0x0a
    je .adv
    cmp dl, 0x0d
    je .adv
    cmp dl, 0x09
    je .adv
    ret
.adv:
    inc qword [rdi + JSONPARSER_POS]
    jmp .loop

; ------------------------------------------------------------------ peek_at
; peek_at(Parser*) -> al = current char (0 at end)
peek_at:
    mov rax, [rdi + JSONPARSER_TEXT]
    mov rcx, [rdi + JSONPARSER_POS]
    movzx eax, byte [rax + rcx]
    ret

; ------------------------------------------------------------------- expect
; expect(Parser*, char) -> eax 0 ok / -1 mismatch; skips ws first
expect:
    PROLOG
    push rbx
    push r12
    mov rbx, rsi
    mov r12, rdi
    call skip_ws
    mov rdi, r12
    call peek_at
    cmp al, bl
    jne .fail
    inc qword [r12 + JSONPARSER_POS]
    xor eax, eax
    jmp .out
.fail:
    mov eax, -1
.out:
    pop r12
    pop rbx
    EPILOG

; ---------------------------------------------------------------- alloc_val
; alloc_val() -> rax zeroed JsonValue* or NULL
alloc_val:
    PROLOG
    mov rdi, 1
    mov rsi, JSONVAL_SIZE
    call calloc
    EPILOG

; forward decl
extern parse_value

; ------------------------------------------------------------- parse_string
; parse_string(Parser*) -> rax malloc'd string or NULL
parse_string:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov r12, rdi
    mov rsi, 0x22
    call expect
    test eax, eax
    jnz .fail0
    mov r13, 32
    mov rdi, r13
    call malloc
    test rax, rax
    jz .fail0
    mov r14, rax
    xor r15, r15
.loop:
    mov rdi, r12
    call peek_at
    test al, al
    jz .fail
    cmp al, 0x22
    je .finish
    inc qword [r12 + JSONPARSER_POS]
    cmp al, 0x5c
    jne .have_char
    mov rdi, r12
    call peek_at
    test al, al
    jz .fail
    inc qword [r12 + JSONPARSER_POS]
    cmp al, 0x22
    je .have_char
    cmp al, 0x5c
    je .have_char
    cmp al, '/'
    je .have_char
    cmp al, 'b'
    je .esc_b
    cmp al, 'f'
    je .esc_f
    cmp al, 'n'
    je .esc_n
    cmp al, 'r'
    je .esc_r
    cmp al, 't'
    je .esc_t
    cmp al, 'u'
    je .esc_u
    jmp .fail
.esc_b:
    mov al, 0x08
    jmp .have_char
.esc_f:
    mov al, 0x0c
    jmp .have_char
.esc_n:
    mov al, 0x0a
    jmp .have_char
.esc_r:
    mov al, 0x0d
    jmp .have_char
.esc_t:
    mov al, 0x09
    jmp .have_char
.esc_u:
    ; read 4 hex digits, produce a single byte (low 8 bits) as this parser
    ; only needs to round-trip ASCII template content. Unrolled (rather than
    ; a counted loop) because peek_at clobbers rcx/rdi, which would otherwise
    ; have to be preserved across each iteration.
    xor ebx, ebx
    READ_HEX_DIGIT
    READ_HEX_DIGIT
    READ_HEX_DIGIT
    READ_HEX_DIGIT
    mov al, bl
.have_char:
    ; Preserve the character: lea/realloc clobber rax/al (caller-saved).
    movzx ebx, al
    lea rax, [r15 + 1]
    cmp rax, r13
    jl .store
    imul r13, r13, 2
    mov rdi, r14
    mov rsi, r13
    call realloc
    test rax, rax
    jz .fail
    mov r14, rax
.store:
    mov byte [r14 + r15], bl
    inc r15
    jmp .loop
.finish:
    inc qword [r12 + JSONPARSER_POS]
    mov byte [r14 + r15], 0
    mov rax, r14
    jmp .out
.fail:
    mov rdi, r14
    call free
.fail0:
    xor eax, eax
.out:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------------------------- parse_number
; parse_number(Parser*) -> rax JsonValue* or NULL
parse_number:
    PROLOG
    push rbx
    push r12
    sub rsp, 16
    mov r12, rdi
    mov rax, [r12 + JSONPARSER_TEXT]
    mov rcx, [r12 + JSONPARSER_POS]
    lea rdi, [rax + rcx]
    lea rsi, [rsp]
    call strtod
    movq rbx, xmm0
    mov rax, [rsp]
    mov rcx, [r12 + JSONPARSER_TEXT]
    sub rax, rcx
    mov [r12 + JSONPARSER_POS], rax
    call alloc_val
    test rax, rax
    jz .out
    mov qword [rax + JSONVAL_TYPE], JSON_T_NUMBER
    movq xmm0, rbx
    movsd [rax + JSONVAL_NUMBER], xmm0
.out:
    add rsp, 16
    pop r12
    pop rbx
    EPILOG

; -------------------------------------------------------------- parse_array
; parse_array(Parser*) -> rax JsonValue* or NULL
parse_array:
    PROLOG
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov r12, rdi
    mov rsi, '['
    call expect
    test eax, eax
    jnz .fail0
    call alloc_val
    test rax, rax
    jz .fail0
    mov rbx, rax
    mov qword [rbx + JSONVAL_TYPE], JSON_T_ARRAY
    mov rdi, r12
    call skip_ws
    mov rdi, r12
    call peek_at
    cmp al, ']'
    jne .loop
    inc qword [r12 + JSONPARSER_POS]
    mov rax, rbx
    jmp .out
.loop:
    mov rdi, r12
    call parse_value
    test rax, rax
    jz .fail
    mov r13, rax
    mov [rsp], r13
    lea rdi, [rbx + JSONVAL_ARR_ITEMS]
    mov rsi, rsp
    mov rdx, 8
    call vec_push
    test eax, eax
    js .fail_item
    mov rdi, r12
    call skip_ws
    mov rdi, r12
    call peek_at
    cmp al, ']'
    jne .want_comma
    inc qword [r12 + JSONPARSER_POS]
    mov rax, rbx
    jmp .out
.want_comma:
    mov rdi, r12
    mov rsi, ','
    call expect
    test eax, eax
    jnz .fail
    jmp .loop
.fail_item:
    mov rdi, r13
    call json_free
.fail:
    mov rdi, rbx
    call json_free
.fail0:
    xor eax, eax
.out:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------------------------- parse_object
; parse_object(Parser*) -> rax JsonValue* or NULL
parse_object:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 16
    mov r12, rdi
    mov rsi, '{'
    call expect
    test eax, eax
    jnz .fail0
    call alloc_val
    test rax, rax
    jz .fail0
    mov rbx, rax
    mov qword [rbx + JSONVAL_TYPE], JSON_T_OBJECT
    mov rdi, r12
    call skip_ws
    mov rdi, r12
    call peek_at
    cmp al, '}'
    jne .loop
    inc qword [r12 + JSONPARSER_POS]
    mov rax, rbx
    jmp .out
.loop:
    mov rdi, r12
    call skip_ws
    mov rdi, r12
    call parse_string
    test rax, rax
    jz .fail
    mov r13, rax
    mov rdi, r12
    call skip_ws
    mov rdi, r12
    mov rsi, ':'
    call expect
    test eax, eax
    jnz .fail_key
    mov rdi, r12
    call parse_value
    test rax, rax
    jz .fail_key
    mov r14, rax
    mov [rsp + 0], r13
    mov [rsp + 8], r14
    lea rdi, [rbx + JSONVAL_OBJ_ENTRIES]
    mov rsi, rsp
    mov rdx, JSONOBJENTRY_SIZE
    call vec_push
    test eax, eax
    js .fail_entry
    mov rdi, r12
    call skip_ws
    mov rdi, r12
    call peek_at
    cmp al, '}'
    jne .want_comma
    inc qword [r12 + JSONPARSER_POS]
    mov rax, rbx
    jmp .out
.want_comma:
    mov rdi, r12
    mov rsi, ','
    call expect
    test eax, eax
    jnz .fail
    jmp .loop
.fail_entry:
    mov rdi, r14
    call json_free
.fail_key:
    mov rdi, r13
    call free
.fail:
    mov rdi, rbx
    call json_free
.fail0:
    xor eax, eax
.out:
    add rsp, 16
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; -------------------------------------------------------------- parse_value
parse_value:
    PROLOG
    push rbx
    push r12
    mov rbx, rdi
    call skip_ws
    mov rdi, rbx
    call peek_at
    cmp al, '{'
    je .is_obj
    cmp al, '['
    je .is_arr
    cmp al, 0x22
    je .is_str
    cmp al, 't'
    je .is_true
    cmp al, 'f'
    je .is_false
    cmp al, 'n'
    je .is_null
    cmp al, '-'
    je .is_num
    cmp al, '0'
    jb .bad
    cmp al, '9'
    ja .bad
    jmp .is_num
.is_obj:
    mov rdi, rbx
    call parse_object
    jmp .out
.is_arr:
    mov rdi, rbx
    call parse_array
    jmp .out
.is_str:
    mov rdi, rbx
    call parse_string
    test rax, rax
    jz .bad
    ; Keep string pointer in callee-saved r12; calloc clobbers rdx.
    mov r12, rax
    mov rdi, 1
    mov rsi, JSONVAL_SIZE
    call calloc
    test rax, rax
    jz .str_oom
    mov qword [rax + JSONVAL_TYPE], JSON_T_STRING
    mov [rax + JSONVAL_STRING], r12
    jmp .out
.str_oom:
    mov rdi, r12
    call free
    xor eax, eax
    jmp .out
.is_true:
    mov rax, [rbx + JSONPARSER_TEXT]
    mov rcx, [rbx + JSONPARSER_POS]
    lea rdi, [rax + rcx]
    lea rsi, [rel lit_true]
    mov rdx, 4
    call strncmp
    test eax, eax
    jnz .bad
    add qword [rbx + JSONPARSER_POS], 4
    mov rdi, 1
    mov rsi, JSONVAL_SIZE
    call calloc
    test rax, rax
    jz .out
    mov qword [rax + JSONVAL_TYPE], JSON_T_BOOL
    mov qword [rax + JSONVAL_BOOL], 1
    jmp .out
.is_false:
    mov rax, [rbx + JSONPARSER_TEXT]
    mov rcx, [rbx + JSONPARSER_POS]
    lea rdi, [rax + rcx]
    lea rsi, [rel lit_false]
    mov rdx, 5
    call strncmp
    test eax, eax
    jnz .bad
    add qword [rbx + JSONPARSER_POS], 5
    mov rdi, 1
    mov rsi, JSONVAL_SIZE
    call calloc
    test rax, rax
    jz .out
    mov qword [rax + JSONVAL_TYPE], JSON_T_BOOL
    mov qword [rax + JSONVAL_BOOL], 0
    jmp .out
.is_null:
    mov rax, [rbx + JSONPARSER_TEXT]
    mov rcx, [rbx + JSONPARSER_POS]
    lea rdi, [rax + rcx]
    lea rsi, [rel lit_null]
    mov rdx, 4
    call strncmp
    test eax, eax
    jnz .bad
    add qword [rbx + JSONPARSER_POS], 4
    mov rdi, 1
    mov rsi, JSONVAL_SIZE
    call calloc
    jmp .out
.is_num:
    mov rdi, rbx
    call parse_number
    jmp .out
.bad:
    xor eax, eax
.out:
    pop r12
    pop rbx
    EPILOG

; ---------------------------------------------------------------- json_parse
; json_parse(text*) -> rax JsonValue* or NULL
json_parse:
    PROLOG
    push rbx
    sub rsp, JSONPARSER_SIZE + 8
    mov qword [rsp + 0], rdi
    mov qword [rsp + 8], 0
    mov rdi, rsp
    call parse_value
    test rax, rax
    jz .out
    mov rbx, rax
    mov rdi, rsp
    call skip_ws
    mov rdi, rsp
    call peek_at
    test al, al
    jz .ok
    mov rdi, rbx
    call json_free
    xor eax, eax
    jmp .out
.ok:
    mov rax, rbx
.out:
    add rsp, JSONPARSER_SIZE + 8
    pop rbx
    EPILOG

; ----------------------------------------------------------------- json_free
json_free:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    test r12, r12
    jz .out
    mov rax, [r12 + JSONVAL_TYPE]
    cmp rax, JSON_T_STRING
    je .free_string
    cmp rax, JSON_T_ARRAY
    je .free_array
    cmp rax, JSON_T_OBJECT
    je .free_object
    jmp .free_self
.free_string:
    mov rdi, [r12 + JSONVAL_STRING]
    call free
    jmp .free_self
.free_array:
    xor rbx, rbx
.arr_loop:
    cmp rbx, [r12 + JSONVAL_ARR_LEN]
    jae .free_arr_items
    mov rax, [r12 + JSONVAL_ARR_ITEMS]
    mov rdi, [rax + rbx*8]
    call json_free
    inc rbx
    jmp .arr_loop
.free_arr_items:
    mov rdi, [r12 + JSONVAL_ARR_ITEMS]
    call free
    jmp .free_self
.free_object:
    xor rbx, rbx
.obj_loop:
    cmp rbx, [r12 + JSONVAL_OBJ_LEN]
    jae .free_obj_entries
    mov rax, [r12 + JSONVAL_OBJ_ENTRIES]
    imul rcx, rbx, JSONOBJENTRY_SIZE
    add rax, rcx
    mov r13, rax
    mov rdi, [r13 + JSONOBJENTRY_KEY]
    call free
    mov rdi, [r13 + JSONOBJENTRY_VALUE]
    call json_free
    inc rbx
    jmp .obj_loop
.free_obj_entries:
    mov rdi, [r12 + JSONVAL_OBJ_ENTRIES]
    call free
.free_self:
    mov rdi, r12
    call free
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------------------------ json_object_get
; json_object_get(obj*, key*) -> rax JsonValue* or NULL
json_object_get:
    PROLOG
    push rbx
    push r12
    push r13
    mov r12, rdi
    mov r13, rsi
    test r12, r12
    jz .null
    mov rax, [r12 + JSONVAL_TYPE]
    cmp rax, JSON_T_OBJECT
    jne .null
    xor rbx, rbx
.loop:
    cmp rbx, [r12 + JSONVAL_OBJ_LEN]
    jae .null
    mov rax, [r12 + JSONVAL_OBJ_ENTRIES]
    imul rcx, rbx, JSONOBJENTRY_SIZE
    add rax, rcx
    mov rdi, [rax + JSONOBJENTRY_KEY]
    mov rsi, r13
    push rax
    call strcmp
    pop rcx
    test eax, eax
    jnz .next
    mov rax, [rcx + JSONOBJENTRY_VALUE]
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

section .note.GNU-stack noexec

section .rodata
lit_true:  db "true"
lit_false: db "false"
lit_null:  db "null"
