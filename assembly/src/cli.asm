; cli.asm - command line entry point (main), option parsing, --check output,
; --template JSON handling, --help text loading.

%include "macros.inc"

section .text

extern malloc
extern free
extern strlen
extern strcmp
extern strchr
extern strrchr
extern memcpy
extern strcpy
extern printf
extern fprintf
extern sprintf
extern exit
extern stderr

extern wl_strdup
extern read_file
extern rtrim_inplace
extern strlist_init
extern strlist_free
extern strlist_push
extern vec_push
extern dictionaries_init
extern dictionaries_free
extern dictionaries_set

extern json_parse
extern json_free
extern json_object_get

extern try_parse_uint

extern wildling_init
extern wildling_free
extern wildling_count
extern wildling_get
extern wildling_next
extern wildling_generators
extern generator_count
extern fopen
extern fclose
extern atoi

global main

; ------------------------------------------------------------- cliargs_init
cliargs_init:
    PROLOG
    push rbx
    push r12
    mov rbx, rdi
    mov qword [rbx + CLIARGS_SELECTS + VEC_ITEMS], 0
    mov qword [rbx + CLIARGS_SELECTS + VEC_LEN], 0
    mov qword [rbx + CLIARGS_SELECTS + VEC_CAP], 0
    mov qword [rbx + CLIARGS_RANGES + VEC_ITEMS], 0
    mov qword [rbx + CLIARGS_RANGES + VEC_LEN], 0
    mov qword [rbx + CLIARGS_RANGES + VEC_CAP], 0
    mov qword [rbx + CLIARGS_CHECK], 0
    mov qword [rbx + CLIARGS_HELP], 0
    mov qword [rbx + CLIARGS_VERSION], 0
    lea rdi, [rbx + CLIARGS_DICTS]
    call dictionaries_init
    lea rdi, [rbx + CLIARGS_PATTERNS]
    call strlist_init
    pop r12
    pop rbx
    EPILOG

; ------------------------------------------------------------- cliargs_free
cliargs_free:
    PROLOG
    push rbx
    push r12
    mov rbx, rdi
    mov rdi, [rbx + CLIARGS_SELECTS + VEC_ITEMS]
    call free
    mov rdi, [rbx + CLIARGS_RANGES + VEC_ITEMS]
    call free
    lea rdi, [rbx + CLIARGS_DICTS]
    call dictionaries_free
    lea rdi, [rbx + CLIARGS_PATTERNS]
    call strlist_free
    pop r12
    pop rbx
    EPILOG

; --------------------------------------------------------------- push_select
; push_select(cliargs*, value:int32) -> eax 0/-1
push_select:
    PROLOG
    push rbx
    push r12
    mov rbx, rdi
    movsxd rax, esi
    sub rsp, 16
    mov [rsp], rax
    lea rdi, [rbx + CLIARGS_SELECTS]
    mov rsi, rsp
    mov rdx, 8
    call vec_push
    add rsp, 16
    pop r12
    pop rbx
    EPILOG

; ---------------------------------------------------------------- push_range
; push_range(cliargs*, Range*) -> eax 0/-1
push_range:
    PROLOG
    lea rdi, [rdi + CLIARGS_RANGES]
    mov rdx, RANGE_SIZE
    call vec_push
    EPILOG

; --------------------------------------------------------------- parse_range
; parse_range(value*, out Range*) -> eax 0/1
parse_range:
    PROLOG
    push rbx
    push r12
    push r13
    sub rsp, 8
    mov rbx, rdi
    mov r13, rsi
    mov rdi, rbx
    mov esi, '-'
    call strchr
    test rax, rax
    jz .false
    cmp rax, rbx
    je .false
    mov r12, rax
    movzx ecx, byte [r12 + 1]
    test cl, cl
    jz .false
    mov rcx, rbx
.val_loop:
    cmp rcx, r12
    jae .val_ok
    movzx eax, byte [rcx]
    cmp al, '0'
    jb .false
    cmp al, '9'
    ja .false
    inc rcx
    jmp .val_loop
.val_ok:
    lea rcx, [r12 + 1]
.val_loop2:
    movzx eax, byte [rcx]
    test al, al
    jz .val_ok2
    cmp al, '0'
    jb .false
    cmp al, '9'
    ja .false
    inc rcx
    jmp .val_loop2
.val_ok2:
    mov rdi, rbx
    mov rsi, r12
    sub rsi, rbx
    call try_parse_uint
    test edx, edx
    jz .false
    mov ebx, eax
    lea rdi, [r12 + 1]
    call strlen
    lea rdi, [r12 + 1]
    mov rsi, rax
    call try_parse_uint
    test edx, edx
    jz .false
    cmp ebx, eax
    jg .false
    movsxd rcx, ebx
    movsxd rdx, eax
    mov [r13 + RANGE_START], rcx
    mov [r13 + RANGE_END], rdx
    mov eax, 1
    jmp .out
.false:
    xor eax, eax
.out:
    add rsp, 8
    pop r13
    pop r12
    pop rbx
    EPILOG

; -------------------------------------------------------- load_dictionary_file
; load_dictionary_file(path*, out StrList*) -> eax 0/-1
load_dictionary_file:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 8
    mov r14, rdi
    mov r13, rsi
    mov rdi, r13
    call strlist_init
    mov rdi, r14
    call read_file
    test rax, rax
    jz .fail0
    mov r12, rax
    mov r14, rax
.line_loop:
    movzx eax, byte [r14]
    test al, al
    jz .done
    mov rbx, r14
.find_eol:
    movzx eax, byte [rbx]
    test al, al
    jz .eol_found
    cmp al, 0x0a
    je .eol_found
    cmp al, 0x0d
    je .eol_found
    inc rbx
    jmp .find_eol
.eol_found:
    movzx r15d, byte [rbx]
    mov byte [rbx], 0
.trim_lead:
    cmp r14, rbx
    jae .trim_lead_done
    movzx eax, byte [r14]
    cmp al, 0x20
    je .is_ws_lead
    cmp al, 0x09
    jb .trim_lead_done
    cmp al, 0x0d
    ja .trim_lead_done
.is_ws_lead:
    inc r14
    jmp .trim_lead
.trim_lead_done:
    mov rax, rbx
.trim_trail:
    cmp rax, r14
    jbe .trim_trail_done
    movzx ecx, byte [rax - 1]
    cmp cl, 0x20
    je .is_ws_trail
    cmp cl, 0x09
    jb .trim_trail_done
    cmp cl, 0x0d
    ja .trim_trail_done
.is_ws_trail:
    dec rax
    jmp .trim_trail
.trim_trail_done:
    mov byte [rax], 0
    movzx eax, byte [r14]
    test al, al
    jz .skip_push
    mov rdi, r13
    mov rsi, r14
    call strlist_push
    test eax, eax
    js .fail
.skip_push:
    mov byte [rbx], r15b
    mov r14, rbx
    movzx eax, byte [r14]
    cmp al, 0x0d
    jne .check_lf
    inc r14
.check_lf:
    movzx eax, byte [r14]
    cmp al, 0x0a
    jne .next_line
    inc r14
.next_line:
    jmp .line_loop
.done:
    mov rdi, r12
    call free
    xor eax, eax
    jmp .out
.fail:
    mov rdi, r12
    call free
    mov rdi, r13
    call strlist_free
    mov eax, -1
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

; -------------------------------------------------------- apply_dictionary_path
; apply_dictionary_path(cliargs*, name*, path*) -> void
apply_dictionary_path:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 32
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov rdi, r14
    lea rsi, [rel mode_r_str]
    call fopen
    test rax, rax
    jz .out
    mov rdi, rax
    call fclose
    mov rdi, r14
    lea rsi, [rsp]
    call load_dictionary_file
    test eax, eax
    jnz .out
    lea rdi, [r12 + CLIARGS_DICTS]
    mov rsi, r13
    lea rdx, [rsp]
    call dictionaries_set
.out:
    add rsp, 32
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; -------------------------------------------------------- apply_dictionary_json
; apply_dictionary_json(cliargs*, name*, value*) -> void
apply_dictionary_json:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 56
    mov r12, rdi
    mov r13, rsi
    mov r14, rdx
    mov rax, [r14 + JSONVAL_TYPE]
    cmp rax, JSON_T_ARRAY
    je .is_array
    cmp rax, JSON_T_STRING
    je .is_string
    jmp .out
.is_array:
    lea rbx, [rsp]
    mov rdi, rbx
    call strlist_init
    xor r15, r15
.arr_loop:
    cmp r15, [r14 + JSONVAL_ARR_LEN]
    jae .arr_done
    mov rax, [r14 + JSONVAL_ARR_ITEMS]
    mov rax, [rax + r15*8]
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_STRING
    je .item_string
    cmp rcx, JSON_T_NUMBER
    je .item_number
    cmp rcx, JSON_T_BOOL
    je .item_bool
    jmp .arr_next
.item_string:
    mov rdi, rbx
    mov rsi, [rax + JSONVAL_STRING]
    call strlist_push
    jmp .arr_next
.item_number:
    movsd xmm0, [rax + JSONVAL_NUMBER]
    cvttsd2si rax, xmm0
    lea rdi, [rsp + 24]
    lea rsi, [rel fmt_lld]
    mov rdx, rax
    call sprintf
    mov rdi, rbx
    lea rsi, [rsp + 24]
    call strlist_push
    jmp .arr_next
.item_bool:
    mov rcx, [rax + JSONVAL_BOOL]
    test rcx, rcx
    jz .bool_false
    lea rsi, [rel true_str]
    jmp .bool_push
.bool_false:
    lea rsi, [rel false_str]
.bool_push:
    mov rdi, rbx
    call strlist_push
.arr_next:
    inc r15
    jmp .arr_loop
.arr_done:
    lea rdi, [r12 + CLIARGS_DICTS]
    mov rsi, r13
    lea rdx, [rsp]
    call dictionaries_set
    jmp .out
.is_string:
    mov rdi, r12
    mov rsi, r13
    mov rdx, [r14 + JSONVAL_STRING]
    call apply_dictionary_path
.out:
    add rsp, 56
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; -------------------------------------------------------------- apply_template
; apply_template(cliargs*, path*) -> void
apply_template:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    mov r12, rdi
    mov r14, rsi
    mov rdi, r14
    call read_file
    test rax, rax
    jnz .have_raw
    mov rdi, [rel stderr]
    lea rsi, [rel tmpl_not_found_fmt]
    mov rdx, r14
    call fprintf
    mov edi, 1
    call exit
.have_raw:
    mov rbx, rax
    mov rdi, rbx
    call json_parse
    mov r13, rax
    mov rdi, rbx
    call free
    test r13, r13
    jz .bad_json
    mov rax, [r13 + JSONVAL_TYPE]
    cmp rax, JSON_T_OBJECT
    je .parse_root
.bad_json:
    mov rdi, r13
    call json_free
    mov rdi, [rel stderr]
    lea rsi, [rel tmpl_invalid_fmt]
    mov rdx, r14
    call fprintf
    mov edi, 1
    call exit
.parse_root:
    mov rdi, r13
    lea rsi, [rel key_check]
    call json_object_get
    test rax, rax
    jz .after_check
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_BOOL
    jne .after_check
    mov rcx, [rax + JSONVAL_BOOL]
    test rcx, rcx
    jz .after_check
    mov qword [r12 + CLIARGS_CHECK], 1
.after_check:
    mov rdi, r13
    lea rsi, [rel key_select]
    call json_object_get
    test rax, rax
    jz .after_select
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_ARRAY
    jne .after_select
    mov rbx, rax
    xor r14, r14
.select_loop:
    cmp r14, [rbx + JSONVAL_ARR_LEN]
    jae .after_select
    mov rax, [rbx + JSONVAL_ARR_ITEMS]
    mov rax, [rax + r14*8]
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_NUMBER
    je .select_num
    cmp rcx, JSON_T_STRING
    je .select_str
    jmp .select_next
.select_num:
    movsd xmm0, [rax + JSONVAL_NUMBER]
    cvttsd2si eax, xmm0
    jmp .select_have_num
.select_str:
    mov rdi, [rax + JSONVAL_STRING]
    call atoi
.select_have_num:
    test eax, eax
    js .select_next
    mov esi, eax
    mov rdi, r12
    call push_select
.select_next:
    inc r14
    jmp .select_loop
.after_select:
    mov rdi, r13
    lea rsi, [rel key_range]
    call json_object_get
    test rax, rax
    jz .after_range
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_ARRAY
    jne .after_range
    mov rbx, rax
    xor r14, r14
    sub rsp, 16
.range_loop:
    cmp r14, [rbx + JSONVAL_ARR_LEN]
    jae .range_loop_done
    mov rax, [rbx + JSONVAL_ARR_ITEMS]
    mov rax, [rax + r14*8]
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_STRING
    jne .range_next
    mov rdi, [rax + JSONVAL_STRING]
    lea rsi, [rsp]
    call parse_range
    test eax, eax
    jz .range_next
    mov rdi, r12
    lea rsi, [rsp]
    call push_range
.range_next:
    inc r14
    jmp .range_loop
.range_loop_done:
    add rsp, 16
.after_range:
    mov rdi, r13
    lea rsi, [rel key_dictionaries]
    call json_object_get
    test rax, rax
    jz .after_dicts
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_OBJECT
    jne .after_dicts
    mov rbx, rax
    xor r14, r14
.dict_loop:
    cmp r14, [rbx + JSONVAL_OBJ_LEN]
    jae .after_dicts
    mov rax, [rbx + JSONVAL_OBJ_ENTRIES]
    imul rcx, r14, JSONOBJENTRY_SIZE
    add rax, rcx
    mov rdi, r12
    mov rsi, [rax + JSONOBJENTRY_KEY]
    mov rdx, [rax + JSONOBJENTRY_VALUE]
    call apply_dictionary_json
    inc r14
    jmp .dict_loop
.after_dicts:
    mov rdi, r13
    lea rsi, [rel key_patterns]
    call json_object_get
    test rax, rax
    jz .after_patterns
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_ARRAY
    jne .after_patterns
    mov rbx, rax
    xor r14, r14
.pattern_loop:
    cmp r14, [rbx + JSONVAL_ARR_LEN]
    jae .after_patterns
    mov rax, [rbx + JSONVAL_ARR_ITEMS]
    mov rax, [rax + r14*8]
    mov rcx, [rax + JSONVAL_TYPE]
    cmp rcx, JSON_T_STRING
    jne .pattern_next
    lea rdi, [r12 + CLIARGS_PATTERNS]
    mov rsi, [rax + JSONVAL_STRING]
    call strlist_push
.pattern_next:
    inc r14
    jmp .pattern_loop
.after_patterns:
    mov rdi, r13
    call json_free
.out:
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ----------------------------------------------------------------- parse_args
; parse_args(argc:int32, argv**, cliargs*) -> void
parse_args:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    movsxd r12, edi
    mov r13, rsi
    mov r14, rdx
    mov rdi, r14
    call cliargs_init
    mov rbx, 1
.arg_loop:
    cmp rbx, r12
    jge .done
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_help]
    call strcmp
    test eax, eax
    jz .set_help
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_help_short]
    call strcmp
    test eax, eax
    jz .set_help
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_version]
    call strcmp
    test eax, eax
    jz .set_version
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_version_short]
    call strcmp
    test eax, eax
    jz .set_version
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_check]
    call strcmp
    test eax, eax
    jz .set_check
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_select]
    call strcmp
    test eax, eax
    jz .do_select
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_range]
    call strcmp
    test eax, eax
    jz .do_range
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_dictionary]
    call strcmp
    test eax, eax
    jz .do_dictionary
    mov rdi, [r13 + rbx*8]
    lea rsi, [rel opt_template]
    call strcmp
    test eax, eax
    jz .do_template
    lea rdi, [r14 + CLIARGS_PATTERNS]
    mov rsi, [r13 + rbx*8]
    call strlist_push
    jmp .next
.set_help:
    mov qword [r14 + CLIARGS_HELP], 1
    jmp .next
.set_version:
    mov qword [r14 + CLIARGS_VERSION], 1
    jmp .next
.set_check:
    mov qword [r14 + CLIARGS_CHECK], 1
    jmp .next
.do_select:
    inc rbx
    cmp rbx, r12
    jge .done
    mov rdi, [r13 + rbx*8]
    call strlen
    mov rsi, rax
    mov rdi, [r13 + rbx*8]
    call try_parse_uint
    test edx, edx
    jz .next
    mov esi, eax
    mov rdi, r14
    call push_select
    jmp .next
.do_range:
    inc rbx
    cmp rbx, r12
    jge .done
    mov rdi, [r13 + rbx*8]
    lea rsi, [rsp]
    call parse_range
    test eax, eax
    jz .next
    mov rdi, r14
    lea rsi, [rsp]
    call push_range
    jmp .next
.do_dictionary:
    inc rbx
    cmp rbx, r12
    jge .done
    mov rdi, [r13 + rbx*8]
    call wl_strdup
    test rax, rax
    jz .next
    mov r15, rax
    mov rdi, r15
    mov esi, ':'
    call strchr
    test rax, rax
    jz .dict_free
    cmp rax, r15
    je .dict_free
    movzx ecx, byte [rax + 1]
    test cl, cl
    jz .dict_free
    mov byte [rax], 0
    mov rdi, r14
    mov rsi, r15
    lea rdx, [rax + 1]
    call apply_dictionary_path
.dict_free:
    mov rdi, r15
    call free
    jmp .next
.do_template:
    inc rbx
    cmp rbx, r12
    jl .template_ok
    mov rdi, [rel stderr]
    lea rsi, [rel tmpl_missing_path]
    call fprintf
    mov edi, 1
    call exit
.template_ok:
    mov rdi, r14
    mov rsi, [r13 + rbx*8]
    call apply_template
.next:
    inc rbx
    jmp .arg_loop
.done:
    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; -------------------------------------------------------------- load_help_text
; load_help_text(argv0*) -> rax malloc'd string
load_help_text:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    sub rsp, 8192
    mov r12, rdi
    mov byte [rsp], 0
    mov byte [rsp + 4096], 0
    test r12, r12
    jz .try_candidates
    mov rdi, r12
    mov esi, '/'
    call strrchr
    test rax, rax
    jz .try_candidates
    mov r13, rax
    mov rax, r13
    sub rax, r12
    cmp rax, 4080
    jge .try_candidates
    mov r14, rax
    mov rdi, rsp
    mov rsi, r12
    mov rdx, r14
    call memcpy
    lea rdi, [rsp + r14]
    lea rsi, [rel help_txt_suffix]
    call strcpy
    lea rdi, [rsp + 4096]
    mov rsi, r12
    mov rdx, r14
    call memcpy
    lea rdi, [rsp + 4096 + r14]
    lea rsi, [rel docs_help_txt_suffix]
    call strcpy
.try_candidates:
    movzx eax, byte [rsp]
    test al, al
    jz .try_docs
    mov rdi, rsp
    call read_file
    test rax, rax
    jnz .out
.try_docs:
    movzx eax, byte [rsp + 4096]
    test al, al
    jz .try_default
    lea rdi, [rsp + 4096]
    call read_file
    test rax, rax
    jnz .out
.try_default:
    lea rdi, [rel docs_help_txt_rel]
    call read_file
    test rax, rax
    jnz .out
    lea rdi, [rel help_fallback_msg]
    call wl_strdup
.out:
    add rsp, 8192
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ----------------------------------------------------------------- print_check
; print_check(cliargs*, wildling*) -> void
print_check:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 24
    mov r12, rdi
    mov r13, rsi

    lea rdi, [rel fmt_patterns_hdr]
    call printf
    xor r14, r14
.p_loop:
    cmp r14, [r12 + CLIARGS_PATTERNS + VEC_LEN]
    jae .p_done
    mov rax, [r12 + CLIARGS_PATTERNS + VEC_ITEMS]
    mov rsi, [rax + r14*8]
    lea rdi, [rel fmt_space_s]
    call printf
    inc r14
    jmp .p_loop
.p_done:
    lea rdi, [rel fmt_nl]
    call printf

    lea rdi, [rel fmt_dicts_hdr]
    call printf
    xor r14, r14
.d_loop:
    cmp r14, [r12 + CLIARGS_DICTS + VEC_LEN]
    jae .d_done
    mov rax, [r12 + CLIARGS_DICTS + VEC_ITEMS]
    imul rcx, r14, DICTENTRY_SIZE
    add rax, rcx
    mov rsi, [rax + DICTENTRY_NAME]
    lea rdi, [rel fmt_space_s]
    call printf
    inc r14
    jmp .d_loop
.d_done:
    lea rdi, [rel fmt_nl]
    call printf

    lea rdi, [rel fmt_select_hdr]
    call printf
    xor r14, r14
.s_loop:
    cmp r14, [r12 + CLIARGS_SELECTS + VEC_LEN]
    jae .s_done
    mov rax, [r12 + CLIARGS_SELECTS + VEC_ITEMS]
    mov rsi, [rax + r14*8]
    lea rdi, [rel fmt_space_d]
    call printf
    inc r14
    jmp .s_loop
.s_done:
    lea rdi, [rel fmt_nl]
    call printf

    lea rdi, [rel fmt_range_hdr]
    call printf
    xor r14, r14
.r_loop:
    cmp r14, [r12 + CLIARGS_RANGES + VEC_LEN]
    jae .r_done
    mov rax, [r12 + CLIARGS_RANGES + VEC_ITEMS]
    imul rcx, r14, RANGE_SIZE
    add rax, rcx
    mov rsi, [rax + RANGE_START]
    mov rdx, [rax + RANGE_END]
    lea rdi, [rel fmt_range_item]
    call printf
    inc r14
    jmp .r_loop
.r_done:
    lea rdi, [rel fmt_nl]
    call printf

    mov rdi, r13
    call wildling_count
    mov esi, eax
    lea rdi, [rel fmt_total]
    call printf

    lea rsi, [rsp]
    mov rdi, r13
    call wildling_generators
    mov rbx, rax
    mov rax, [rsp]
    mov [rsp + 8], rax
    xor r14, r14
.g_loop:
    cmp r14, [rsp + 8]
    jae .g_done
    imul rax, r14, GENERATOR_SIZE
    add rax, rbx
    mov r15, [rax + GENERATOR_SOURCE]
    mov rdi, rax
    call generator_count
    mov edx, eax
    mov rsi, r15
    lea rdi, [rel fmt_generator_line]
    call printf
    inc r14
    jmp .g_loop
.g_done:
    lea rdi, [rel fmt_nl]
    call printf

    add rsp, 24
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

; ---------------------------------------------------------------------- main
main:
    PROLOG
    push rbx
    push r12
    push r13
    push r14
    push r15
    sub rsp, 168
    mov r12, rsi
    lea rdx, [rsp]
    call parse_args
    lea r13, [rsp]

    mov rax, [r13 + CLIARGS_HELP]
    test rax, rax
    jz .not_help
    mov rdi, [r12]
    call load_help_text
    mov [rsp + 144], rax
    mov rdi, rax
    call rtrim_inplace
    mov rsi, [rsp + 144]
    lea rdi, [rel fmt_s_nl]
    call printf
    mov rdi, [rsp + 144]
    call free
    mov rdi, r13
    call cliargs_free
    xor eax, eax
    jmp .out
.not_help:
    mov rax, [r13 + CLIARGS_VERSION]
    test rax, rax
    jz .not_version
    lea rdi, [rel fmt_version]
    lea rsi, [rel version_str]
    call printf
    mov rdi, r13
    call cliargs_free
    xor eax, eax
    jmp .out
.not_version:
    cmp qword [r13 + CLIARGS_PATTERNS + VEC_LEN], 0
    jne .have_patterns
    mov rdi, [rel stderr]
    lea rsi, [rel no_pattern_msg]
    call fprintf
    mov rdi, r13
    call cliargs_free
    mov eax, 1
    jmp .out
.have_patterns:
    lea rbx, [rsp + 120]
    mov rdi, rbx
    mov rsi, [r13 + CLIARGS_PATTERNS + VEC_ITEMS]
    mov rdx, [r13 + CLIARGS_PATTERNS + VEC_LEN]
    lea rcx, [r13 + CLIARGS_DICTS]
    call wildling_init
    test eax, eax
    jns .init_ok
    mov rdi, [rel stderr]
    lea rsi, [rel init_fail_msg]
    call fprintf
    mov rdi, r13
    call cliargs_free
    mov eax, 1
    jmp .out
.init_ok:
    mov rax, [r13 + CLIARGS_CHECK]
    test rax, rax
    jz .not_check
    mov rdi, r13
    mov rsi, rbx
    call print_check
    mov rdi, rbx
    call wildling_free
    mov rdi, r13
    call cliargs_free
    xor eax, eax
    jmp .out
.not_check:
    mov rax, [r13 + CLIARGS_SELECTS + VEC_LEN]
    or rax, [r13 + CLIARGS_RANGES + VEC_LEN]
    jz .plain_loop
    mov qword [rsp + 160], 0
    xor r14, r14
.sel_out_loop:
    cmp r14, [r13 + CLIARGS_SELECTS + VEC_LEN]
    jae .range_out_loop_init
    mov rax, [r13 + CLIARGS_SELECTS + VEC_ITEMS]
    mov rsi, [rax + r14*8]
    mov [rsp + 152], rsi
    mov rdi, rbx
    call wildling_get
    test rax, rax
    jz .sel_false
    mov [rsp + 144], rax
    mov rsi, rax
    lea rdi, [rel fmt_s_nl]
    call printf
    mov rdi, [rsp + 144]
    call free
    jmp .sel_next
.sel_false:
    mov rdi, [rel stderr]
    lea rsi, [rel oor_fmt]
    mov rdx, [rsp + 152]
    xor eax, eax
    call fprintf
    mov qword [rsp + 160], 1
.sel_next:
    inc r14
    jmp .sel_out_loop
.range_out_loop_init:
    xor r14, r14
.range_out_loop:
    cmp r14, [r13 + CLIARGS_RANGES + VEC_LEN]
    jae .out_selrange_done
    mov rax, [r13 + CLIARGS_RANGES + VEC_ITEMS]
    imul rcx, r14, RANGE_SIZE
    add rax, rcx
    mov r12, [rax + RANGE_START]
    mov r15, [rax + RANGE_END]
.range_inner:
    cmp r12, r15
    jg .range_inner_done
    mov rdi, rbx
    mov esi, r12d
    call wildling_get
    test rax, rax
    jz .range_false
    mov [rsp + 144], rax
    mov rsi, rax
    lea rdi, [rel fmt_s_nl]
    call printf
    mov rdi, [rsp + 144]
    call free
    jmp .range_inner_next
.range_false:
    mov rdi, [rel stderr]
    lea rsi, [rel oor_fmt]
    mov rdx, r12
    xor eax, eax
    call fprintf
    mov qword [rsp + 160], 1
.range_inner_next:
    inc r12
    jmp .range_inner
.range_inner_done:
    inc r14
    jmp .range_out_loop
.out_selrange_done:
    mov rdi, rbx
    call wildling_free
    mov rdi, r13
    call cliargs_free
    mov eax, [rsp + 160]
    jmp .out
.plain_loop:
    mov rdi, rbx
    call wildling_next
    test rax, rax
    jz .plain_done
    mov [rsp + 144], rax
    mov rsi, rax
    lea rdi, [rel fmt_s_nl]
    call printf
    mov rdi, [rsp + 144]
    call free
    jmp .plain_loop
.plain_done:
    mov rdi, rbx
    call wildling_free
    mov rdi, r13
    call cliargs_free
    xor eax, eax
.out:
    add rsp, 168
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    EPILOG

section .note.GNU-stack noexec

section .rodata
mode_r_str:            db "r", 0
fmt_lld:                db "%lld", 0
true_str:               db "true", 0
false_str:              db "false", 0
false_nl:               db "false", 10, 0
oor_fmt:                db "out of range: %lld", 10, 0
fmt_s_nl:               db "%s", 10, 0
fmt_space_s:            db " %s", 0
fmt_space_d:            db " %lld", 0
fmt_nl:                 db 10, 0
fmt_patterns_hdr:       db "patterns:", 0
fmt_dicts_hdr:          db "dictionaries:", 0
fmt_select_hdr:         db "select:", 0
fmt_range_hdr:          db "range:", 0
fmt_range_item:         db " %lld-%lld", 0
fmt_total:              db "total: %d", 0
fmt_generator_line:     db 10, "generator: %s %d", 0
fmt_version:            db "wildling %s", 10, 0
version_str:            db "2.0.4", 0
no_pattern_msg:         db "No pattern provided. Use --help for usage information.", 10, 0
init_fail_msg:          db "Failed to initialize wildling", 10, 0
tmpl_not_found_fmt:     db "Template file not found: %s", 10, 0
tmpl_invalid_fmt:       db "Invalid JSON template: %s", 10, 0
tmpl_missing_path:      db "Missing path for --template", 10, 0
key_check:              db "check", 0
key_select:             db "select", 0
key_range:              db "range", 0
key_dictionaries:       db "dictionaries", 0
key_patterns:           db "patterns", 0
opt_help:               db "--help", 0
opt_help_short:         db "-h", 0
opt_version:            db "--version", 0
opt_version_short:      db "-v", 0
opt_check:              db "--check", 0
opt_select:             db "--select", 0
opt_range:              db "--range", 0
opt_dictionary:         db "--dictionary", 0
opt_template:           db "--template", 0
help_txt_suffix:        db "/help.txt", 0
docs_help_txt_suffix:   db "/../docs/help.txt", 0
docs_help_txt_rel:      db "docs/help.txt", 0
help_fallback_msg:      db "wildling - pattern based string generator", 10, 10, "Help text unavailable.", 10, 0
