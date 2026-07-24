; parse_pattern.asm - hand-rolled (no POSIX regex) pattern splitting and
; per-piece tokenizer construction. Mirrors rust/src/parse_pattern.rs.

%include "macros.inc"

section .text

extern malloc
extern free
extern strlen
extern wl_strdup
extern wl_strndup
extern strlist_init
extern strlist_free
extern strlist_push
extern strlist_push_owned
extern vec_push
extern dictionaries_get
extern dictionaries_has
extern token_options_init
extern token_options_free
extern token_init
extern token_free

global tokenlist_free
global parse_pattern
global try_parse_uint
global is_special

; -------------------------------------------------------------- is_special
; is_special(c) -- edi = char code -> eax 0/1
is_special:
    cmp dil, '#'
    je .yes
    cmp dil, '@'
    je .yes
    cmp dil, '$'
    je .yes
    cmp dil, '*'
    je .yes
    cmp dil, '&'
    je .yes
    cmp dil, '?'
    je .yes
    cmp dil, '!'
    je .yes
    cmp dil, '-'
    je .yes
    cmp dil, '%'
    je .yes
    xor eax, eax
    ret
.yes:
    mov eax, 1
    ret

; ------------------------------------------------------------ push_substr
; push_substr(list*, ptr, len) -> eax 0/-1
push_substr:
    PROLOG
    push rbx
    push r12
    mov r12, rdi
    mov rdi, rsi
    mov rsi, rdx
    call wl_strndup
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

; ------------------------------------------------------- try_parse_uint
; try_parse_uint(ptr, len) -> eax=value, edx=1 valid / 0 invalid
try_parse_uint:
    push rbx
    push r12
    mov r12, rdi
    mov rbx, rsi
    xor eax, eax
    test rbx, rbx
    jz .invalid
    xor rcx, rcx
.loop:
    cmp rcx, rbx
    jae .valid
    movzx edx, byte [r12 + rcx]
    cmp dl, '0'
    jb .invalid
    cmp dl, '9'
    ja .invalid
    imul eax, eax, 10
    sub dl, '0'
    add eax, edx
    inc rcx
    jmp .loop
.valid:
    mov edx, 1
    jmp .out
.invalid:
    xor eax, eax
    xor edx, edx
.out:
    pop r12
    pop rbx
    ret

; ----------------------------------------------- split_keeping_delimiters
; split_keeping_delimiters(input*, parts_out*) -> eax 0/-1
; Hand-rolled equivalent of splitting on:
;   (\[%@$*#&?!-]|[%@$*#&?!-]\{[^}]*\}|[%@$*#&?!-])
; while keeping the delimiters as their own pieces.
split_keeping_delimiters:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r12, rdi
    mov r13, rsi
    mov rdi, r13
    call strlist_init
    mov rdi, r12
    call strlen
    mov ebx, eax
    xor r14d, r14d
    xor r15d, r15d
.scan_loop:
    cmp r14d, ebx
    jae .scan_done
    movzx eax, byte [r12 + r14]
    cmp al, 0x5c
    jne .check_brace
    lea edx, [r14 + 1]
    cmp edx, ebx
    jae .check_brace
    movzx eax, byte [r12 + rdx]
    mov edi, eax
    call is_special
    test eax, eax
    jz .check_brace
    cmp r14d, r15d
    jbe .esc_no_prefix
    mov rdi, r13
    lea rsi, [r12 + r15]
    mov edx, r14d
    sub edx, r15d
    call push_substr
    test eax, eax
    js .fail
.esc_no_prefix:
    mov rdi, r13
    lea rsi, [r12 + r14]
    mov edx, 2
    call push_substr
    test eax, eax
    js .fail
    add r14d, 2
    mov r15d, r14d
    jmp .scan_loop
.check_brace:
    movzx eax, byte [r12 + r14]
    mov edi, eax
    call is_special
    test eax, eax
    jz .advance
    lea edx, [r14 + 1]
    cmp edx, ebx
    jae .bare_special
    movzx eax, byte [r12 + rdx]
    cmp al, '{'
    jne .bare_special
    lea ecx, [r14 + 2]
.brace_scan:
    cmp ecx, ebx
    jae .bare_special
    movzx eax, byte [r12 + rcx]
    cmp al, '}'
    je .brace_closed
    inc ecx
    jmp .brace_scan
.brace_closed:
    ; ecx = index of closing '}' — must survive push_substr (caller-saved).
    mov dword [rsp], ecx
    cmp r14d, r15d
    jbe .brace_no_prefix
    mov rdi, r13
    lea rsi, [r12 + r15]
    mov edx, r14d
    sub edx, r15d
    call push_substr
    test eax, eax
    js .fail
.brace_no_prefix:
    mov rdi, r13
    lea rsi, [r12 + r14]
    mov edx, dword [rsp]
    sub edx, r14d
    inc edx
    call push_substr
    test eax, eax
    js .fail
    mov ecx, dword [rsp]
    lea r14d, [ecx + 1]
    mov r15d, r14d
    jmp .scan_loop
.bare_special:
    cmp r14d, r15d
    jbe .bare_no_prefix
    mov rdi, r13
    lea rsi, [r12 + r15]
    mov edx, r14d
    sub edx, r15d
    call push_substr
    test eax, eax
    js .fail
.bare_no_prefix:
    mov rdi, r13
    lea rsi, [r12 + r14]
    mov edx, 1
    call push_substr
    test eax, eax
    js .fail
    inc r14d
    mov r15d, r14d
    jmp .scan_loop
.advance:
    inc r14d
    jmp .scan_loop
.scan_done:
    cmp r15d, ebx
    jae .ok
    mov rdi, r13
    lea rsi, [r12 + r15]
    mov edx, ebx
    sub edx, r15d
    call push_substr
    test eax, eax
    js .fail
.ok:
    xor eax, eax
    jmp .out
.fail:
    mov rdi, r13
    call strlist_free
    mov eax, -1
.out:
    add rsp, 8
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------------- chars_as_variants
; chars_as_variants(str*, out*) -> eax 0/-1
chars_as_variants:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov rdi, r13
    call strlist_init
.loop:
    movzx eax, byte [r12]
    test al, al
    jz .done
    mov rdi, r12
    mov rsi, 1
    call wl_strndup
    test rax, rax
    jz .fail
    mov rdi, r13
    mov rsi, rax
    call strlist_push_owned
    test eax, eax
    js .fail
    inc r12
    jmp .loop
.done:
    xor eax, eax
    jmp .out
.fail:
    mov rdi, r13
    call strlist_free
    mov eax, -1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------- parse_length_with_variants
; parse_length_with_variants(part*, variants*, opts_out*) -> eax 0/-1
; Always consumes variants (moves it into opts on success or frees it on
; failure).
parse_length_with_variants:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov rdi, r14
    call token_options_init

    mov rax, [r13 + VEC_ITEMS]
    mov [r14 + TOKENOPTS_VARIANTS + VEC_ITEMS], rax
    mov rax, [r13 + VEC_LEN]
    mov [r14 + TOKENOPTS_VARIANTS + VEC_LEN], rax
    mov rax, [r13 + VEC_CAP]
    mov [r14 + TOKENOPTS_VARIANTS + VEC_CAP], rax
    mov qword [r13 + VEC_ITEMS], 0
    mov qword [r13 + VEC_LEN], 0
    mov qword [r13 + VEC_CAP], 0

    mov rdi, r12
    call wl_strdup
    test rax, rax
    jz .fail
    mov [r14 + TOKENOPTS_SRC], rax

    mov dword [r14 + TOKENOPTS_HAS_START], 1
    mov dword [r14 + TOKENOPTS_HAS_END], 1

    mov rdi, r12
    call strlen
    mov ebx, eax
    xor ecx, ecx
.find_open:
    cmp ecx, ebx
    jae .ok
    cmp byte [r12 + rcx], '{'
    je .found_open
    inc ecx
    jmp .find_open
.found_open:
    lea edx, [ecx + 1]
.find_close:
    cmp edx, ebx
    jae .ok
    cmp byte [r12 + rdx], '}'
    je .found_close
    inc edx
    jmp .find_close
.found_close:
    lea eax, [ecx + 1]
    mov r8d, eax
    mov r9d, edx
    sub r9d, eax
    xor r10d, r10d
.find_dash:
    cmp r10d, r9d
    jae .no_dash
    lea rax, [r8 + r10]
    movzx eax, byte [r12 + rax]
    cmp al, '-'
    je .has_dash
    inc r10d
    jmp .find_dash
.has_dash:
    lea rdi, [r12 + r8]
    movsxd rsi, r10d
    call try_parse_uint
    test edx, edx
    jz .ok
    mov ebx, eax
    mov eax, r8d
    add eax, r10d
    inc eax
    lea rdi, [r12 + rax]
    mov esi, r9d
    sub esi, r10d
    dec esi
    call try_parse_uint
    test edx, edx
    jz .ok
    mov dword [r14 + TOKENOPTS_START_LEN], ebx
    mov dword [r14 + TOKENOPTS_END_LEN], eax
    jmp .ok
.no_dash:
    lea rdi, [r12 + r8]
    movsxd rsi, r9d
    call try_parse_uint
    test edx, edx
    jz .ok
    mov dword [r14 + TOKENOPTS_START_LEN], eax
    mov dword [r14 + TOKENOPTS_END_LEN], eax
.ok:
    xor eax, eax
    jmp .out
.fail:
    lea rdi, [r14 + TOKENOPTS_VARIANTS]
    call strlist_free
    mov eax, -1
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; --------------------------------------------- parse_length_with_string
; parse_length_with_string(part*, opts_out*) -> eax 1 matched / 0 no match / -1 error
; Only touches opts_out when it returns 1 (or -1 after having partially
; filled it in, in which case it cleans up after itself).
;
; Locals (48 bytes): +0 content_start +8 content_len +16 before_start
; +24 before_len +32 dash_start_value +40 dash_idx
parse_length_with_string:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 48
    mov r12, rdi
    mov r13, rsi
    mov rdi, r12
    call strlen
    mov r14d, eax

    xor ecx, ecx
.find_open:
    lea eax, [ecx + 1]
    cmp eax, r14d
    jae .no_match
    cmp byte [r12 + rcx], '{'
    jne .find_open_next
    cmp byte [r12 + rcx + 1], 0x27
    je .found_open
.find_open_next:
    inc ecx
    jmp .find_open
.found_open:
    lea edx, [ecx + 2]
    cmp edx, r14d
    jae .no_match
    mov eax, r14d
    dec eax
.rfind_quote:
    cmp eax, edx
    jl .no_match
    cmp byte [r12 + rax], 0x27
    je .found_close
    dec eax
    jmp .rfind_quote
.found_close:
    mov dword [rsp + 0], edx
    mov ecx, eax
    sub ecx, edx
    mov dword [rsp + 8], ecx
    lea esi, [eax + 1]
    cmp esi, r14d
    jae .no_match
    movzx eax, byte [r12 + rsi]
    cmp al, '}'
    je .have_no_suffix
    cmp al, ','
    je .have_comma
    jmp .no_match

.have_comma:
    lea edx, [esi + 1]
    mov ecx, r14d
    sub ecx, edx
    cmp ecx, 0
    jle .before_brace_set
    mov eax, r14d
    dec eax
    cmp byte [r12 + rax], '}'
    jne .before_brace_set
    dec ecx
.before_brace_set:
    mov dword [rsp + 16], edx
    mov dword [rsp + 24], ecx
    mov rdi, r13
    call token_options_init
    mov eax, dword [rsp + 16]
    mov ecx, dword [rsp + 24]
    xor edx, edx
.find_dash2:
    cmp edx, ecx
    jae .no_dash2
    lea rsi, [rax + rdx]
    movzx esi, byte [r12 + rsi]
    cmp sil, '-'
    je .has_dash2
    inc edx
    jmp .find_dash2
.has_dash2:
    mov dword [rsp + 40], edx
    lea rdi, [r12 + rax]
    movsxd rsi, edx
    call try_parse_uint
    test edx, edx
    jz .build
    mov dword [rsp + 32], eax
    mov eax, dword [rsp + 16]
    mov ecx, dword [rsp + 40]
    lea rdi, [rax + rcx]
    lea rdi, [r12 + rdi]
    inc rdi
    mov esi, dword [rsp + 24]
    sub esi, ecx
    dec esi
    call try_parse_uint
    test edx, edx
    jz .build
    mov ecx, dword [rsp + 32]
    mov dword [r13 + TOKENOPTS_START_LEN], ecx
    mov dword [r13 + TOKENOPTS_END_LEN], eax
    jmp .build
.no_dash2:
    mov eax, dword [rsp + 16]
    lea rdi, [r12 + rax]
    movsxd rsi, dword [rsp + 24]
    call try_parse_uint
    test edx, edx
    jz .build
    mov dword [r13 + TOKENOPTS_START_LEN], eax
    mov dword [r13 + TOKENOPTS_END_LEN], eax
    jmp .build

.have_no_suffix:
    mov rdi, r13
    call token_options_init
    jmp .build

.build:
    mov dword [r13 + TOKENOPTS_HAS_START], 1
    mov dword [r13 + TOKENOPTS_HAS_END], 1
    mov eax, dword [rsp + 0]
    lea rdi, [r12 + rax]
    movsxd rsi, dword [rsp + 8]
    call wl_strndup
    test rax, rax
    jz .fail
    mov [r13 + TOKENOPTS_STRING], rax
    mov rdi, r12
    call wl_strdup
    test rax, rax
    jz .fail_free_string
    mov [r13 + TOKENOPTS_SRC], rax
    mov eax, 1
    jmp .out
.fail_free_string:
    mov rdi, [r13 + TOKENOPTS_STRING]
    call free
    mov qword [r13 + TOKENOPTS_STRING], 0
    jmp .fail
.no_match:
    xor eax, eax
    jmp .out
.fail:
    mov eax, -1
.out:
    add rsp, 48
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ---------------------------------------------------------- make_literal_token
; make_literal_token(part*, out_token*) -> eax 0/-1
make_literal_token:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 64
    mov r12, rdi
    mov r13, rsi
    lea r14, [rsp]
    mov rdi, r14
    call token_options_init
    mov rdi, r12
    call wl_strdup
    test rax, rax
    jz .fail
    mov [r14 + TOKENOPTS_SRC], rax
    lea rdi, [r14 + TOKENOPTS_VARIANTS]
    mov rsi, r12
    call strlist_push
    test eax, eax
    js .fail_opts
    mov dword [r14 + TOKENOPTS_HAS_START], 1
    mov dword [r14 + TOKENOPTS_HAS_END], 1
    mov dword [r14 + TOKENOPTS_START_LEN], 1
    mov dword [r14 + TOKENOPTS_END_LEN], 1
    mov rdi, r13
    mov rsi, r14
    call token_init
    jmp .out
.fail_opts:
    mov rdi, r14
    call token_options_free
    mov eax, -1
    jmp .out
.fail:
    mov eax, -1
.out:
    add rsp, 64
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------------------- dictionary_tokenizer
; dictionary_tokenizer(part*, dictionaries*, out_token*) -> eax 0/-1
dictionary_tokenizer:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 64
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    lea rbx, [rsp]
    mov rdi, r12
    mov rsi, rbx
    call parse_length_with_string
    cmp eax, 0
    jl .fail
    jz .fallback_literal
    mov rax, [rbx + TOKENOPTS_STRING]
    movzx ecx, byte [rax]
    test cl, cl
    jz .use_dict
    mov rdi, r13
    mov rsi, rax
    call dictionaries_has
    test eax, eax
    jnz .use_dict
    mov rdi, rbx
    call token_options_free
    mov rdi, r12
    mov rsi, r14
    call make_literal_token
    jmp .out
.use_dict:
    mov rdi, r13
    mov rsi, [rbx + TOKENOPTS_STRING]
    call dictionaries_get
    test rax, rax
    jz .do_init
    mov r12, rax
    xor r13, r13
.copy_loop:
    cmp r13, [r12 + VEC_LEN]
    jae .do_init
    lea rdi, [rbx + TOKENOPTS_VARIANTS]
    mov rax, [r12 + VEC_ITEMS]
    mov rsi, [rax + r13*8]
    call strlist_push
    test eax, eax
    js .fail_opts
    inc r13
    jmp .copy_loop
.do_init:
    mov rdi, r14
    mov rsi, rbx
    call token_init
    jmp .out
.fallback_literal:
    mov rdi, r12
    mov rsi, r14
    call make_literal_token
    jmp .out
.fail_opts:
    mov rdi, rbx
    call token_options_free
    mov eax, -1
    jmp .out
.fail:
    mov eax, -1
.out:
    add rsp, 64
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; --------------------------------------------------- unescape_comma_inplace
; unescape_comma_inplace(str*) -- replaces "\," with "," in place, no return
unescape_comma_inplace:
    push rbx
    push r12
    mov r12, rdi
    mov rbx, rdi
.loop:
    movzx eax, byte [r12]
    test al, al
    jz .done
    cmp al, 0x5c
    jne .copy
    movzx edx, byte [r12 + 1]
    cmp dl, ','
    jne .copy
    mov byte [rbx], ','
    inc rbx
    add r12, 2
    jmp .loop
.copy:
    mov byte [rbx], al
    inc rbx
    inc r12
    jmp .loop
.done:
    mov byte [rbx], 0
    pop r12
    pop rbx
    ret

; ------------------------------------------------------------ words_tokenizer
; words_tokenizer(part*, out_token*) -> eax 0/-1
;
; Locals: +0..56 TokenOptions, +64 cursor, +72 total_len
words_tokenizer:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 88
    mov r12, rdi
    mov r13, rsi
    lea rbx, [rsp]
    mov rdi, r12
    mov rsi, rbx
    call parse_length_with_string
    cmp eax, 0
    jl .fail
    jz .fallback

    mov r14, [rbx + TOKENOPTS_STRING]
    mov rdi, r14
    call strlen
    mov qword [rsp + 72], rax
    xor r15, r15
    mov qword [rsp + 64], 0
.split_loop:
    mov rax, [rsp + 64]
    cmp rax, [rsp + 72]
    jae .split_done
    lea rcx, [rax + 1]
    cmp rcx, [rsp + 72]
    jae .check_comma
    movzx edx, byte [r14 + rax]
    cmp dl, 0x5c
    jne .check_comma
    movzx edx, byte [r14 + rcx]
    cmp dl, ','
    jne .check_comma
    mov [rsp + 64], rcx
    add qword [rsp + 64], 1
    jmp .split_loop
.check_comma:
    movzx edx, byte [r14 + rax]
    cmp dl, ','
    jne .advance_cursor
    lea rdi, [rbx + TOKENOPTS_VARIANTS]
    lea rsi, [r14 + r15]
    mov rdx, rax
    sub rdx, r15
    lea rcx, [rax + 1]
    mov r15, rcx
    mov [rsp + 64], rcx
    call push_substr
    test eax, eax
    js .fail_opts
    jmp .split_loop
.advance_cursor:
    add qword [rsp + 64], 1
    jmp .split_loop
.split_done:
    lea rdi, [rbx + TOKENOPTS_VARIANTS]
    lea rsi, [r14 + r15]
    mov rdx, [rsp + 72]
    sub rdx, r15
    call push_substr
    test eax, eax
    js .fail_opts

    xor r15, r15
.unescape_loop:
    cmp r15, [rbx + TOKENOPTS_VARIANTS + VEC_LEN]
    jae .after_unescape
    mov rax, [rbx + TOKENOPTS_VARIANTS + VEC_ITEMS]
    mov rdi, [rax + r15*8]
    call unescape_comma_inplace
    inc r15
    jmp .unescape_loop
.after_unescape:
    mov rdi, r13
    mov rsi, rbx
    call token_init
    jmp .out

.fallback:
    mov rdi, r12
    mov rsi, r13
    call make_literal_token
    jmp .out
.fail_opts:
    mov rdi, rbx
    call token_options_free
    mov eax, -1
    jmp .out
.fail:
    mov eax, -1
.out:
    add rsp, 88
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ----------------------------------------------------------- simple_tokenizer
; simple_tokenizer(part*, alphabet*, out_token*) -> eax 0/-1
;
; Locals: +0 variants_tmp StrList (24 bytes), +24 TokenOptions (56 bytes)
simple_tokenizer:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 80
    mov r12, rdi
    mov r14, rsi
    mov r13, rdx
    lea rbx, [rsp]
    mov rdi, r14
    mov rsi, rbx
    call chars_as_variants
    test eax, eax
    js .fail
    mov rdi, r12
    mov rsi, rbx
    lea rdx, [rsp + 24]
    call parse_length_with_variants
    test eax, eax
    js .fail
    mov rdi, r13
    lea rsi, [rsp + 24]
    call token_init
    jmp .out
.fail:
    mov eax, -1
.out:
    add rsp, 80
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; --------------------------------------------------------------- part_to_token
; part_to_token(part*, dictionaries*, out_token*) -> eax 0/-1
;
; Locals: +0 TokenOptions (56 bytes, used only by the escaped-literal path)
part_to_token:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 64
    mov rbx, rdi
    mov r12, rsi
    mov r13, rdx
    movzx eax, byte [rbx]
    test al, al
    jz .literal
    cmp al, '#'
    je .digits
    cmp al, '@'
    je .lower
    cmp al, '*'
    je .lowernum
    cmp al, '-'
    je .alnum
    cmp al, '!'
    je .upper
    cmp al, '?'
    je .upnum
    cmp al, '&'
    je .letters
    cmp al, '%'
    je .dict
    cmp al, '$'
    je .words
    cmp al, 0x5c
    jne .literal
    movzx ecx, byte [rbx + 1]
    test cl, cl
    jz .literal
    mov edi, ecx
    call is_special
    test eax, eax
    jz .literal
    jmp .escaped
.digits:
    mov rdi, rbx
    lea rsi, [rel digits_str]
    mov rdx, r13
    call simple_tokenizer
    jmp .out
.lower:
    mov rdi, rbx
    lea rsi, [rel lower_str]
    mov rdx, r13
    call simple_tokenizer
    jmp .out
.lowernum:
    mov rdi, rbx
    lea rsi, [rel lowernum_str]
    mov rdx, r13
    call simple_tokenizer
    jmp .out
.alnum:
    mov rdi, rbx
    lea rsi, [rel alnum_str]
    mov rdx, r13
    call simple_tokenizer
    jmp .out
.upper:
    mov rdi, rbx
    lea rsi, [rel upper_str]
    mov rdx, r13
    call simple_tokenizer
    jmp .out
.upnum:
    mov rdi, rbx
    lea rsi, [rel upnum_str]
    mov rdx, r13
    call simple_tokenizer
    jmp .out
.letters:
    mov rdi, rbx
    lea rsi, [rel letters_str]
    mov rdx, r13
    call simple_tokenizer
    jmp .out
.dict:
    mov rdi, rbx
    mov rsi, r12
    mov rdx, r13
    call dictionary_tokenizer
    jmp .out
.words:
    mov rdi, rbx
    mov rsi, r13
    call words_tokenizer
    jmp .out
.literal:
    mov rdi, rbx
    mov rsi, r13
    call make_literal_token
    jmp .out
.escaped:
    lea r14, [rsp]
    mov rdi, r14
    call token_options_init
    lea rdi, [r14 + TOKENOPTS_VARIANTS]
    lea rsi, [rbx + 1]
    call strlist_push
    test eax, eax
    js .escaped_fail
    mov rdi, rbx
    call wl_strdup
    test rax, rax
    jz .escaped_fail
    mov [r14 + TOKENOPTS_SRC], rax
    mov dword [r14 + TOKENOPTS_HAS_START], 1
    mov dword [r14 + TOKENOPTS_HAS_END], 1
    mov dword [r14 + TOKENOPTS_START_LEN], 1
    mov dword [r14 + TOKENOPTS_END_LEN], 1
    mov rdi, r13
    mov rsi, r14
    call token_init
    jmp .out
.escaped_fail:
    mov rdi, r14
    call token_options_free
    mov eax, -1
.out:
    add rsp, 64
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------------------------- tokenlist_free
tokenlist_free:
    PROLOG
    push rbx
    push r12
    mov r12, rdi
    test r12, r12
    jz .clear
    xor rbx, rbx
.loop:
    cmp rbx, [r12 + TOKENLIST_LEN]
    jae .free_arr
    mov rax, [r12 + TOKENLIST_ITEMS]
    imul rcx, rbx, TOKEN_SIZE
    add rax, rcx
    mov rdi, rax
    call token_free
    inc rbx
    jmp .loop
.free_arr:
    mov rdi, [r12 + TOKENLIST_ITEMS]
    call free
.clear:
    mov qword [r12 + TOKENLIST_ITEMS], 0
    mov qword [r12 + TOKENLIST_LEN], 0
    mov qword [r12 + TOKENLIST_CAP], 0
.out:
    pop r12
    pop rbx
    EPILOG

; ---------------------------------------------------------------- parse_pattern
; parse_pattern(input_pattern*, dictionaries*, out TokenList*) -> eax 0/-1
;
; Locals: +0 StrList parts (24 bytes), +24 Token temp (48 bytes)
parse_pattern:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 72
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov qword [r14 + TOKENLIST_ITEMS], 0
    mov qword [r14 + TOKENLIST_LEN], 0
    mov qword [r14 + TOKENLIST_CAP], 0
    lea rbx, [rsp]
    mov rdi, r12
    mov rsi, rbx
    call split_keeping_delimiters
    test eax, eax
    js .fail
    xor r15, r15
.loop:
    cmp r15, [rbx + VEC_LEN]
    jae .done
    mov rax, [rbx + VEC_ITEMS]
    mov rax, [rax + r15*8]
    movzx ecx, byte [rax]
    test cl, cl
    jz .next
    mov rdi, rax
    mov rsi, r13
    lea rdx, [rsp + 24]
    call part_to_token
    test eax, eax
    js .fail_parts
    mov rdi, r14
    lea rsi, [rsp + 24]
    mov rdx, TOKEN_SIZE
    call vec_push
    test eax, eax
    js .fail_push
.next:
    inc r15
    jmp .loop
.done:
    mov rdi, rbx
    call strlist_free
    xor eax, eax
    jmp .out
.fail_push:
    lea rdi, [rsp + 24]
    call token_free
.fail_parts:
    mov rdi, rbx
    call strlist_free
    mov rdi, r14
    call tokenlist_free
    mov eax, -1
    jmp .out
.fail:
    mov eax, -1
.out:
    add rsp, 72
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

section .note.GNU-stack noexec

section .rodata
digits_str:   db "0123456789", 0
lower_str:    db "abcdefghijklmnopqrstuvwxyz", 0
lowernum_str: db "abcdefghijklmnopqrstuvwxyz0123456789", 0
alnum_str:    db "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", 0
upper_str:    db "ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
upnum_str:    db "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", 0
letters_str:  db "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ", 0
