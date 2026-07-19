; x86-64 System V ABI helpers for wildling NASM port

%macro CARG1 1
    mov %1, rdi
%endmacro

%macro CARG2 2
    mov %1, rdi
    mov %2, rsi
%endmacro

%macro CARG3 3
    mov %1, rdi
    mov %2, rsi
    mov %3, rdx
%endmacro

%macro RET0 0
    xor eax, eax
    ret
%endmacro

%macro RET_NEG1 0
    mov eax, -1
    ret
%endmacro

%macro RET_NULL 0
    xor rax, rax
    ret
%endmacro

%macro RET_TRUE 0
    mov eax, 1
    ret
%endmacro

%macro RET_FALSE 0
    xor eax, eax
    ret
%endmacro

; Struct field offsets (gcc x86-64)
%define STRLIST_ITEMS     0
%define STRLIST_LEN       8
%define STRLIST_CAP       16
%define STRLIST_SIZE      24

%define TOKEN_SRC         0
%define TOKEN_START_LEN   8
%define TOKEN_END_LEN     12
%define TOKEN_VARIANTS    16
%define TOKEN_COUNT       40
%define TOKEN_SIZE        48

%define TOKENLIST_ITEMS   0
%define TOKENLIST_LEN     8
%define TOKENLIST_CAP     16
%define TOKENLIST_SIZE    24

%define GENERATOR_SOURCE  0
%define GENERATOR_TOKENS  8
%define GENERATOR_COUNT   32
%define GENERATOR_SIZE    40

%define WILDLING_GENS         0
%define WILDLING_GENS_LEN     8
%define WILDLING_PATTERN_CNT  16
%define WILDLING_INTERNAL_IDX 20
%define WILDLING_SIZE         24

%define DICTENTRY_NAME    0
%define DICTENTRY_WORDS   8
%define DICTENTRY_SIZE    32

%define DICTIONARIES_ITEMS 0
%define DICTIONARIES_LEN   8
%define DICTIONARIES_CAP   16
%define DICTIONARIES_SIZE  24

%define TOKENOPTS_STRING      0
%define TOKENOPTS_START_LEN   8
%define TOKENOPTS_END_LEN     12
%define TOKENOPTS_HAS_START   16
%define TOKENOPTS_HAS_END     20
%define TOKENOPTS_VARIANTS    24
%define TOKENOPTS_SRC         48
%define TOKENOPTS_SIZE        56

; Generic growable vector (items ptr / len / cap), element size supplied
; per-call to vec_push. Reused for StrList, Dictionaries, selects, ranges,
; JSON arrays and JSON object entries.
%define VEC_ITEMS         0
%define VEC_LEN           8
%define VEC_CAP           16
%define VEC_SIZE          24

%define RANGE_START       0
%define RANGE_END         8
%define RANGE_SIZE        16

; JsonValue
%define JSON_T_NULL       0
%define JSON_T_BOOL       1
%define JSON_T_NUMBER     2
%define JSON_T_STRING     3
%define JSON_T_ARRAY      4
%define JSON_T_OBJECT     5

%define JSONVAL_TYPE        0
%define JSONVAL_BOOL        8
%define JSONVAL_NUMBER      16
%define JSONVAL_STRING      24
%define JSONVAL_ARR_ITEMS   32
%define JSONVAL_ARR_LEN     40
%define JSONVAL_ARR_CAP     48
%define JSONVAL_OBJ_ENTRIES 56
%define JSONVAL_OBJ_LEN     64
%define JSONVAL_OBJ_CAP     72
%define JSONVAL_SIZE        80

%define JSONOBJENTRY_KEY    0
%define JSONOBJENTRY_VALUE  8
%define JSONOBJENTRY_SIZE   16

%define JSONPARSER_TEXT     0
%define JSONPARSER_POS      8
%define JSONPARSER_SIZE     16

; CliArgs
%define CLIARGS_SELECTS   0
%define CLIARGS_RANGES    24
%define CLIARGS_CHECK     48
%define CLIARGS_DICTS     56
%define CLIARGS_PATTERNS  80
%define CLIARGS_HELP      104
%define CLIARGS_VERSION   112
%define CLIARGS_SIZE      120

; Maintain 16-byte stack alignment before libc calls (SysV ABI).
%macro PROLOG 0
    push rbp
    mov rbp, rsp
%endmacro

%macro EPILOG 0
    mov rsp, rbp
    pop rbp
    ret
%endmacro

%macro EPILOG_NEG1 0
    mov rsp, rbp
    pop rbp
    RET_NEG1
%endmacro

%macro EPILOG_NULL 0
    mov rsp, rbp
    pop rbp
    RET_NULL
%endmacro

; Read one hex digit from JSON parser at r12; shift into ebx (used by json.asm).
%macro READ_HEX_DIGIT 0
    mov rdi, r12
    call peek_at
    test al, al
    jz parse_string.fail
    inc qword [r12 + JSONPARSER_POS]
    cmp al, '0'
    jb parse_string.fail
    cmp al, '9'
    jbe %%digit
    cmp al, 'a'
    jb parse_string.fail
    cmp al, 'f'
    ja parse_string.fail
    sub al, 'a'
    add al, 10
    jmp %%store
%%digit:
    sub al, '0'
%%store:
    shl ebx, 4
    or bl, al
%endmacro
