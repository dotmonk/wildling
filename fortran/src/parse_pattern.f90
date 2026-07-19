! Hand-rolled pattern split and tokenizers (no regex).
module wl_parse_pattern
  use iso_fortran_env, only: int64
  use wl_util
  use wl_token
  implicit none
  private

  public :: token_list, token_list_free, parse_pattern
  public :: chars_as_variants

  type :: token_list
    type(token_t), allocatable :: items(:)
    integer :: n = 0
  end type token_list

contains

  subroutine token_list_free(list)
    type(token_list), intent(inout) :: list
    integer :: i
    if (allocated(list%items)) then
      do i = 1, list%n
        call token_free(list%items(i))
      end do
      deallocate(list%items)
    end if
    list%n = 0
  end subroutine token_list_free

  subroutine token_list_push(list, tok)
    type(token_list), intent(inout) :: list
    type(token_t), intent(inout) :: tok
    type(token_t), allocatable :: tmp(:)
    integer :: new_cap, i, old_cap
    old_cap = 0
    if (allocated(list%items)) old_cap = size(list%items)
    if (list%n >= old_cap) then
      if (old_cap == 0) then
        new_cap = 4
      else
        new_cap = old_cap * 2
      end if
      allocate(tmp(new_cap))
      do i = 1, list%n
        tmp(i) = list%items(i)
        ! prevent double-free of moved components
        call str_list_init(list%items(i)%variants)
        if (allocated(list%items(i)%src)) deallocate(list%items(i)%src)
      end do
      call move_alloc(tmp, list%items)
    end if
    list%n = list%n + 1
    list%items(list%n) = tok
    call str_list_init(tok%variants)
    if (allocated(tok%src)) deallocate(tok%src)
  end subroutine token_list_push

  subroutine chars_as_variants(s, out)
    character(len=*), intent(in) :: s
    type(str_list), intent(out) :: out
    integer :: i
    call str_list_init(out)
    do i = 1, len(s)
      call str_list_push(out, s(i:i))
    end do
  end subroutine chars_as_variants

  pure logical function is_special(c) result(ok)
    character(len=1), intent(in) :: c
    ok = (index('#@$*&?!-%', c) > 0)
  end function is_special

  subroutine split_keeping_delimiters(input, parts)
    character(len=*), intent(in) :: input
    type(str_list), intent(out) :: parts
    integer :: i, j, literal_start, n
    character(len=1) :: c

    call str_list_init(parts)
    n = len(input)
    if (n == 0) return

    i = 1
    literal_start = 1
    do while (i <= n)
      c = input(i:i)
      if (c == '\' .and. i + 1 <= n .and. is_special(input(i+1:i+1))) then
        if (i > literal_start) call str_list_push(parts, input(literal_start:i-1))
        call str_list_push(parts, input(i:i+1))
        i = i + 2
        literal_start = i
      else if (is_special(c) .and. i + 1 <= n .and. input(i+1:i+1) == '{') then
        if (i > literal_start) call str_list_push(parts, input(literal_start:i-1))
        j = i + 2
        do while (j <= n .and. input(j:j) /= '}')
          j = j + 1
        end do
        if (j <= n .and. input(j:j) == '}') then
          call str_list_push(parts, input(i:j))
          i = j + 1
          literal_start = i
        else
          if (i > literal_start) call str_list_push(parts, input(literal_start:i-1))
          call str_list_push(parts, c)
          i = i + 1
          literal_start = i
        end if
      else if (is_special(c)) then
        if (i > literal_start) call str_list_push(parts, input(literal_start:i-1))
        call str_list_push(parts, c)
        i = i + 1
        literal_start = i
      else
        i = i + 1
      end if
    end do
    if (literal_start <= n) call str_list_push(parts, input(literal_start:n))
  end subroutine split_keeping_delimiters

  subroutine parse_length_with_variants(part, start_length, end_length)
    character(len=*), intent(in) :: part
    integer, intent(out) :: start_length, end_length
    integer :: open_pos, close_pos, dash_pos, s, e, nn
    character(len=:), allocatable :: inner, left, right

    start_length = 1
    end_length = 1
    open_pos = index(part, '{')
    if (open_pos == 0) return
    close_pos = index(part, '}')
    if (close_pos == 0 .or. close_pos < open_pos) return
    inner = part(open_pos+1:close_pos-1)
    dash_pos = index(inner, '-')
    if (dash_pos > 0) then
      left = inner(1:dash_pos-1)
      right = inner(dash_pos+1:)
      if (try_parse_int(left, s) .and. try_parse_int(right, e)) then
        start_length = s
        end_length = e
      end if
    else if (try_parse_int(inner, nn)) then
      start_length = nn
      end_length = nn
    end if
  end subroutine parse_length_with_variants

  logical function parse_length_with_string(part, content, start_length, end_length) result(ok)
    character(len=*), intent(in) :: part
    character(len=:), allocatable, intent(out) :: content
    integer, intent(out) :: start_length, end_length
    integer :: open_pos, after_open, close_quote, i, dash_pos, s, e, nn
    character(len=:), allocatable :: rest, after_quote, stripped, left, right

    ok = .false.
    start_length = 1
    end_length = 1
    content = ''

    open_pos = index(part, "{'")
    if (open_pos == 0) return

    after_open = open_pos + 2
    rest = part(after_open:)
    close_quote = 0
    do i = len(rest), 1, -1
      if (rest(i:i) == "'") then
        close_quote = i
        exit
      end if
    end do
    if (close_quote == 0) return

    content = rest(1:close_quote-1)
    after_quote = rest(close_quote+1:)

    if (len(after_quote) == 0) then
      return
    end if
    if (after_quote(1:1) /= '}' .and. after_quote(1:1) /= ',') then
      if (index(after_quote, '}') == 0) return
    end if

    if (after_quote(1:1) == ',') then
      stripped = after_quote(2:)
      if (len(stripped) > 0 .and. stripped(len(stripped):len(stripped)) == '}') then
        stripped = stripped(1:len(stripped)-1)
      end if
      dash_pos = index(stripped, '-')
      if (dash_pos > 0) then
        left = stripped(1:dash_pos-1)
        right = stripped(dash_pos+1:)
        if (try_parse_int(left, s) .and. try_parse_int(right, e)) then
          start_length = s
          end_length = e
        end if
      else if (try_parse_int(stripped, nn)) then
        start_length = nn
        end_length = nn
      end if
    else if (after_quote(1:1) /= '}') then
      return
    end if

    ok = .true.
  end function parse_length_with_string

  subroutine make_literal_token(part, tok)
    character(len=*), intent(in) :: part
    type(token_t), intent(out) :: tok
    type(str_list) :: variants
    call str_list_init(variants)
    call str_list_push(variants, part)
    call token_init(tok, part, 1, 1, variants)
  end subroutine make_literal_token

  subroutine simple_tokenizer(part, alphabet, tok)
    character(len=*), intent(in) :: part, alphabet
    type(token_t), intent(out) :: tok
    type(str_list) :: variants
    integer :: start_length, end_length
    call chars_as_variants(alphabet, variants)
    call parse_length_with_variants(part, start_length, end_length)
    call token_init(tok, part, start_length, end_length, variants)
  end subroutine simple_tokenizer

  subroutine dictionary_tokenizer(part, dicts, tok)
    character(len=*), intent(in) :: part
    type(dictionaries), intent(in) :: dicts
    type(token_t), intent(out) :: tok
    character(len=:), allocatable :: content
    integer :: start_length, end_length
    type(str_list) :: variants

    if (.not. parse_length_with_string(part, content, start_length, end_length)) then
      call make_literal_token(part, tok)
      return
    end if
    if (len(content) > 0 .and. .not. dictionaries_has(dicts, content)) then
      call make_literal_token(part, tok)
      return
    end if

    variants = dictionaries_get(dicts, content)
    ! deep copy already; ensure we own a fresh list for token_init transfer
    call token_init(tok, part, start_length, end_length, variants)
  end subroutine dictionary_tokenizer

  function unescape_commas(s) result(out)
    character(len=*), intent(in) :: s
    character(len=:), allocatable :: out
    integer :: i
    out = ''
    i = 1
    do while (i <= len(s))
      if (i < len(s) .and. s(i:i) == '\' .and. s(i+1:i+1) == ',') then
        out = out // ','
        i = i + 2
      else
        out = out // s(i:i)
        i = i + 1
      end if
    end do
  end function unescape_commas

  subroutine words_tokenizer(part, tok)
    character(len=*), intent(in) :: part
    type(token_t), intent(out) :: tok
    character(len=:), allocatable :: content, work
    integer :: start_length, end_length, idx, i
    type(str_list) :: variants
    character(len=:), allocatable :: piece

    if (.not. parse_length_with_string(part, content, start_length, end_length)) then
      call make_literal_token(part, tok)
      return
    end if

    call str_list_init(variants)
    work = content
    idx = 1
    do while (idx <= len(work))
      if (idx < len(work) .and. work(idx:idx) == '\' .and. work(idx+1:idx+1) == ',') then
        idx = idx + 2
      else if (work(idx:idx) == ',') then
        piece = work(1:idx-1)
        call str_list_push(variants, piece)
        work = work(idx+1:)
        idx = 1
      else
        idx = idx + 1
      end if
    end do
    call str_list_push(variants, work)

    do i = 1, variants%n
      variants%items(i)%s = unescape_commas(variants%items(i)%s)
    end do

    call token_init(tok, part, start_length, end_length, variants)
  end subroutine words_tokenizer

  subroutine part_to_token(part, dicts, tok)
    character(len=*), intent(in) :: part
    type(dictionaries), intent(in) :: dicts
    type(token_t), intent(out) :: tok
    character(len=1) :: first
    type(str_list) :: variants

    if (len(part) == 0) then
      call make_literal_token(part, tok)
      return
    end if

    first = part(1:1)
    select case (first)
    case ('#')
      call simple_tokenizer(part, '0123456789', tok)
    case ('@')
      call simple_tokenizer(part, 'abcdefghijklmnopqrstuvwxyz', tok)
    case ('*')
      call simple_tokenizer(part, 'abcdefghijklmnopqrstuvwxyz0123456789', tok)
    case ('-')
      call simple_tokenizer(part, &
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', tok)
    case ('!')
      call simple_tokenizer(part, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ', tok)
    case ('?')
      call simple_tokenizer(part, 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789', tok)
    case ('&')
      call simple_tokenizer(part, &
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ', tok)
    case ('%')
      call dictionary_tokenizer(part, dicts, tok)
    case ('$')
      call words_tokenizer(part, tok)
    case default
      if (len(part) > 1 .and. part(1:1) == '\' .and. is_special(part(2:2))) then
        call str_list_init(variants)
        call str_list_push(variants, part(2:))
        call token_init(tok, part, 1, 1, variants)
      else
        call make_literal_token(part, tok)
      end if
    end select
  end subroutine part_to_token

  subroutine parse_pattern(input_pattern, dicts, out)
    character(len=*), intent(in) :: input_pattern
    type(dictionaries), intent(in) :: dicts
    type(token_list), intent(out) :: out
    type(str_list) :: parts
    type(token_t) :: tok
    integer :: i

    out%n = 0
    if (allocated(out%items)) deallocate(out%items)

    call split_keeping_delimiters(input_pattern, parts)
    do i = 1, parts%n
      if (len(parts%items(i)%s) == 0) cycle
      call part_to_token(parts%items(i)%s, dicts, tok)
      call token_list_push(out, tok)
    end do
    call str_list_free(parts)
  end subroutine parse_pattern

end module wl_parse_pattern
