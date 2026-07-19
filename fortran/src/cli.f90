! wildling CLI entry point.
program wildling_cli
  use iso_fortran_env, only: int64, error_unit, output_unit
  use wl_util
  use wl_json
  use wl_generator
  use wl_wildling
  implicit none

  type :: range_t
    integer :: start_idx = 0
    integer :: end_idx = 0
  end type range_t

  type :: cli_args
    integer, allocatable :: selects(:)
    integer :: nselect = 0
    type(range_t), allocatable :: ranges(:)
    integer :: nrange = 0
    logical :: check = .false.
    type(dictionaries) :: dicts
    type(str_list) :: patterns
    logical :: help = .false.
    logical :: version = .false.
  end type cli_args

  type(cli_args) :: args
  type(wildling_t) :: w
  character(len=:), allocatable :: value, help_text
  integer :: i, j, exit_code
  logical :: ok, oor

  interface
    subroutine c_exit(status) bind(c, name="exit")
      integer, value :: status
    end subroutine c_exit
  end interface

  call parse_args(args)
  exit_code = 0
  oor = .false.

  if (args%help) then
    help_text = load_help_text()
    write(*, '(A)') help_text
    call cli_args_free(args)
    stop 0
  end if

  if (args%version) then
    write(*, '(A)') 'wildling ' // WILDLING_VERSION
    call cli_args_free(args)
    stop 0
  end if

  if (args%patterns%n == 0) then
    write(error_unit, '(A)') &
      'No pattern provided. Use --help for usage information.'
    call cli_args_free(args)
    stop 1
  end if

  call wildling_init(w, args%patterns, args%dicts)

  if (args%check) then
    call print_check(args, w)
  else if (args%nselect > 0 .or. args%nrange > 0) then
    do i = 1, args%nselect
      call print_value_or_oor(w, int(args%selects(i), int64), oor)
    end do
    do i = 1, args%nrange
      do j = args%ranges(i)%start_idx, args%ranges(i)%end_idx
        call print_value_or_oor(w, int(j, int64), oor)
      end do
    end do
    if (oor) exit_code = 1
  else
    do
      ok = wildling_next(w, value)
      if (.not. ok) exit
      write(*, '(A)') value
    end do
  end if

  call wildling_free(w)
  call cli_args_free(args)
  if (exit_code /= 0) call c_exit(exit_code)

contains

  subroutine cli_args_init(a)
    type(cli_args), intent(out) :: a
    a%nselect = 0
    a%nrange = 0
    a%check = .false.
    a%help = .false.
    a%version = .false.
    call dictionaries_init(a%dicts)
    call str_list_init(a%patterns)
  end subroutine cli_args_init

  subroutine cli_args_free(a)
    type(cli_args), intent(inout) :: a
    if (allocated(a%selects)) deallocate(a%selects)
    if (allocated(a%ranges)) deallocate(a%ranges)
    call dictionaries_free(a%dicts)
    call str_list_free(a%patterns)
  end subroutine cli_args_free

  subroutine push_select(a, v)
    type(cli_args), intent(inout) :: a
    integer, intent(in) :: v
    integer, allocatable :: tmp(:)
    integer :: cap
    cap = 0
    if (allocated(a%selects)) cap = size(a%selects)
    if (a%nselect >= cap) then
      if (cap == 0) then
        allocate(tmp(4))
      else
        allocate(tmp(cap * 2))
        tmp(1:cap) = a%selects
      end if
      call move_alloc(tmp, a%selects)
    end if
    a%nselect = a%nselect + 1
    a%selects(a%nselect) = v
  end subroutine push_select

  subroutine push_range(a, r)
    type(cli_args), intent(inout) :: a
    type(range_t), intent(in) :: r
    type(range_t), allocatable :: tmp(:)
    integer :: cap
    cap = 0
    if (allocated(a%ranges)) cap = size(a%ranges)
    if (a%nrange >= cap) then
      if (cap == 0) then
        allocate(tmp(4))
      else
        allocate(tmp(cap * 2))
        tmp(1:cap) = a%ranges
      end if
      call move_alloc(tmp, a%ranges)
    end if
    a%nrange = a%nrange + 1
    a%ranges(a%nrange) = r
  end subroutine push_range

  logical function parse_range(value, r) result(ok)
    character(len=*), intent(in) :: value
    type(range_t), intent(out) :: r
    integer :: dash, i, start_n, end_n
    character(len=:), allocatable :: left, right
    ok = .false.
    dash = index(value, '-')
    if (dash <= 1 .or. dash == len(value)) return
    left = value(1:dash-1)
    right = value(dash+1:)
    do i = 1, len(left)
      if (.not. is_digit(left(i:i))) return
    end do
    do i = 1, len(right)
      if (.not. is_digit(right(i:i))) return
    end do
    if (.not. try_parse_int(left, start_n)) return
    if (.not. try_parse_int(right, end_n)) return
    if (start_n > end_n) return
    r%start_idx = start_n
    r%end_idx = end_n
    ok = .true.
  end function parse_range

  function get_arg(i) result(s)
    integer, intent(in) :: i
    character(len=:), allocatable :: s
    integer :: n
    call get_command_argument(i, length=n)
    allocate(character(len=n) :: s)
    if (n > 0) call get_command_argument(i, value=s)
  end function get_arg

  subroutine load_dictionary_file(path, words, ok)
    character(len=*), intent(in) :: path
    type(str_list), intent(out) :: words
    logical, intent(out) :: ok
    character(len=:), allocatable :: raw, line, t
    integer :: i
    call str_list_init(words)
    raw = read_file(path, ok)
    if (.not. ok) return
    line = ''
    i = 1
    do while (i <= len(raw))
      if (raw(i:i) == achar(13)) then
        t = trim_ends(line)
        if (len(t) > 0) call str_list_push(words, t)
        line = ''
        if (i < len(raw) .and. raw(i+1:i+1) == achar(10)) i = i + 1
      else if (raw(i:i) == achar(10)) then
        t = trim_ends(line)
        if (len(t) > 0) call str_list_push(words, t)
        line = ''
      else
        line = line // raw(i:i)
      end if
      i = i + 1
    end do
    t = trim_ends(line)
    if (len(t) > 0) call str_list_push(words, t)
    ok = .true.
  end subroutine load_dictionary_file

  function trim_ends(s) result(out)
    character(len=*), intent(in) :: s
    character(len=:), allocatable :: out
    integer :: a, b
    a = 1
    b = len(s)
    do while (a <= b .and. is_space(s(a:a)))
      a = a + 1
    end do
    do while (b >= a .and. is_space(s(b:b)))
      b = b - 1
    end do
    if (a > b) then
      out = ''
    else
      out = s(a:b)
    end if
  end function trim_ends

  subroutine apply_dictionary_path(a, name, path)
    type(cli_args), intent(inout) :: a
    character(len=*), intent(in) :: name, path
    type(str_list) :: words
    logical :: ok
    if (.not. file_exists(path)) return
    call load_dictionary_file(path, words, ok)
    if (ok) call dictionaries_set(a%dicts, name, words)
  end subroutine apply_dictionary_path

  subroutine apply_dictionary_json(a, name, value)
    type(cli_args), intent(inout) :: a
    character(len=*), intent(in) :: name
    type(json_value), intent(in) :: value
    type(str_list) :: words
    integer :: i
    character(len=:), allocatable :: buf
    if (value%value_type == JSON_ARRAY) then
      call str_list_init(words)
      do i = 1, value%array_len
        select case (value%array_items(i)%value_type)
        case (JSON_STRING)
          call str_list_push(words, value%array_items(i)%string_value)
        case (JSON_NUMBER)
          buf = int_to_str(int(value%array_items(i)%number_value))
          call str_list_push(words, buf)
        case (JSON_BOOL)
          if (value%array_items(i)%bool_value) then
            call str_list_push(words, 'true')
          else
            call str_list_push(words, 'false')
          end if
        end select
      end do
      call dictionaries_set(a%dicts, name, words)
    else if (value%value_type == JSON_STRING) then
      call apply_dictionary_path(a, name, value%string_value)
    end if
  end subroutine apply_dictionary_json

  subroutine apply_template(a, path)
    type(cli_args), intent(inout) :: a
    character(len=*), intent(in) :: path
    character(len=:), allocatable :: raw
    type(json_value), pointer :: root, node, dicts
    logical :: ok
    integer :: i, number
    type(range_t) :: r

    if (.not. file_exists(path)) then
      write(error_unit, '(A)') 'Template file not found: ' // path
      stop 1
    end if
    raw = read_file(path, ok)
    if (.not. ok) then
      write(error_unit, '(A)') 'Template file not found: ' // path
      stop 1
    end if
    root => json_parse(raw)
    if (.not. associated(root) .or. root%value_type /= JSON_OBJECT) then
      if (associated(root)) call json_free(root)
      write(error_unit, '(A)') 'Invalid JSON template: ' // path
      stop 1
    end if

    node => json_object_get(root, 'check')
    if (associated(node)) then
      if (node%value_type == JSON_BOOL .and. node%bool_value) a%check = .true.
    end if

    node => json_object_get(root, 'select')
    if (associated(node) .and. node%value_type == JSON_ARRAY) then
      do i = 1, node%array_len
        number = -1
        if (node%array_items(i)%value_type == JSON_NUMBER) then
          number = int(node%array_items(i)%number_value)
        else if (node%array_items(i)%value_type == JSON_STRING) then
          if (.not. try_parse_int(node%array_items(i)%string_value, number)) number = -1
        end if
        if (number >= 0) call push_select(a, number)
      end do
    end if

    node => json_object_get(root, 'range')
    if (associated(node) .and. node%value_type == JSON_ARRAY) then
      do i = 1, node%array_len
        if (node%array_items(i)%value_type == JSON_STRING) then
          if (parse_range(node%array_items(i)%string_value, r)) call push_range(a, r)
        end if
      end do
    end if

    dicts => json_object_get(root, 'dictionaries')
    if (associated(dicts) .and. dicts%value_type == JSON_OBJECT) then
      do i = 1, dicts%object_len
        if (associated(dicts%object_entries(i)%value)) then
          call apply_dictionary_json(a, dicts%object_entries(i)%key, &
            dicts%object_entries(i)%value)
        end if
      end do
    end if

    node => json_object_get(root, 'patterns')
    if (associated(node) .and. node%value_type == JSON_ARRAY) then
      do i = 1, node%array_len
        if (node%array_items(i)%value_type == JSON_STRING) then
          call str_list_push(a%patterns, node%array_items(i)%string_value)
        end if
      end do
    end if

    call json_free(root)
  end subroutine apply_template

  subroutine parse_args(a)
    type(cli_args), intent(out) :: a
    integer :: i, n, val, colon
    character(len=:), allocatable :: arg, spec, name, path
    type(range_t) :: r

    call cli_args_init(a)
    n = command_argument_count()
    i = 1
    do while (i <= n)
      arg = get_arg(i)
      if (arg == '--help' .or. arg == '-h') then
        a%help = .true.
        i = i + 1
      else if (arg == '--version' .or. arg == '-v') then
        a%version = .true.
        i = i + 1
      else if (arg == '--check') then
        a%check = .true.
        i = i + 1
      else if (arg == '--select') then
        i = i + 1
        if (i > n) exit
        arg = get_arg(i)
        if (try_parse_int(arg, val) .and. val >= 0) call push_select(a, val)
        i = i + 1
      else if (arg == '--range') then
        i = i + 1
        if (i > n) exit
        arg = get_arg(i)
        if (parse_range(arg, r)) call push_range(a, r)
        i = i + 1
      else if (arg == '--dictionary') then
        i = i + 1
        if (i > n) exit
        spec = get_arg(i)
        colon = index(spec, ':')
        if (colon > 1 .and. colon < len(spec)) then
          name = spec(1:colon-1)
          path = spec(colon+1:)
          call apply_dictionary_path(a, name, path)
        end if
        i = i + 1
      else if (arg == '--template') then
        i = i + 1
        if (i > n) then
          write(error_unit, '(A)') 'Missing path for --template'
          stop 1
        end if
        call apply_template(a, get_arg(i))
        i = i + 1
      else
        call str_list_push(a%patterns, arg)
        i = i + 1
      end if
    end do
  end subroutine parse_args

  function load_help_text() result(text)
    character(len=:), allocatable :: text
    character(len=:), allocatable :: exe, dir, cand
    integer :: n, slash, i
    logical :: ok

    call get_command_argument(0, length=n)
    allocate(character(len=max(n, 1)) :: exe)
    if (n > 0) then
      call get_command_argument(0, value=exe)
    else
      exe = ''
    end if

    dir = ''
    slash = 0
    do i = len(exe), 1, -1
      if (exe(i:i) == '/') then
        slash = i
        exit
      end if
    end do
    if (slash > 0) dir = exe(1:slash)

    do i = 1, 3
      select case (i)
      case (1)
        if (len(dir) > 0) then
          cand = dir // 'help.txt'
        else
          cand = 'help.txt'
        end if
      case (2)
        if (len(dir) > 0) then
          cand = dir // '../docs/help.txt'
        else
          cand = '../docs/help.txt'
        end if
      case default
        cand = 'docs/help.txt'
      end select
      text = read_file(cand, ok)
      if (ok) then
        text = rtrim_copy(text)
        return
      end if
    end do
    text = 'wildling - pattern based string generator' // achar(10) // achar(10) // &
           'Help text unavailable.'
  end function load_help_text

  function format_list(values) result(out)
    type(str_list), intent(in) :: values
    character(len=:), allocatable :: out
    integer :: i
    if (values%n == 0) then
      out = ''
      return
    end if
    out = ' '
    do i = 1, values%n
      if (i > 1) out = out // ' '
      out = out // values%items(i)%s
    end do
  end function format_list

  subroutine print_check(a, w)
    type(cli_args), intent(in) :: a
    type(wildling_t), intent(in) :: w
    type(str_list) :: dict_names, select_strs, range_strs
    character(len=:), allocatable :: patterns_s, dicts_s, select_s, range_s
    integer :: i

    call dictionaries_names(a%dicts, dict_names)
    call str_list_init(select_strs)
    do i = 1, a%nselect
      call str_list_push(select_strs, int_to_str(a%selects(i)))
    end do
    call str_list_init(range_strs)
    do i = 1, a%nrange
      call str_list_push(range_strs, &
        int_to_str(a%ranges(i)%start_idx) // '-' // int_to_str(a%ranges(i)%end_idx))
    end do

    patterns_s = format_list(a%patterns)
    dicts_s = format_list(dict_names)
    select_s = format_list(select_strs)
    range_s = format_list(range_strs)

    write(*, '(A)') 'patterns:' // patterns_s
    write(*, '(A)') 'dictionaries:' // dicts_s
    write(*, '(A)') 'select:' // select_s
    write(*, '(A)') 'range:' // range_s
    write(*, '(A,I0)', advance='no') 'total: ', wildling_count(w)
    do i = 1, w%ngen
      write(*, '(A)', advance='no') achar(10) // 'generator: ' // &
        w%generators(i)%source // ' '
      write(*, '(I0)', advance='no') generator_count(w%generators(i))
    end do
    write(*, '(A)') ''

    call str_list_free(dict_names)
    call str_list_free(select_strs)
    call str_list_free(range_strs)
  end subroutine print_check

  subroutine print_value_or_oor(w, index, oor)
    type(wildling_t), intent(in) :: w
    integer(int64), intent(in) :: index
    logical, intent(inout) :: oor
    character(len=:), allocatable :: value
    if (wildling_get(w, index, value)) then
      write(*, '(A)') value
    else
      write(error_unit, '(A,I0)') 'out of range: ', index
      oor = .true.
    end if
  end subroutine print_value_or_oor

end program wildling_cli
