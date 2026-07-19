! Minimal JSON parser for --template (ISO Fortran only).
module wl_json
  use wl_util
  implicit none
  private

  public :: JSON_NULL, JSON_BOOL, JSON_NUMBER, JSON_STRING, JSON_ARRAY, JSON_OBJECT
  public :: json_value, json_object_entry
  public :: json_parse, json_free, json_object_get

  integer, parameter :: JSON_NULL = 0
  integer, parameter :: JSON_BOOL = 1
  integer, parameter :: JSON_NUMBER = 2
  integer, parameter :: JSON_STRING = 3
  integer, parameter :: JSON_ARRAY = 4
  integer, parameter :: JSON_OBJECT = 5

  type :: json_value
    integer :: value_type = JSON_NULL
    logical :: bool_value = .false.
    real(kind=kind(1.0d0)) :: number_value = 0.0d0
    character(len=:), allocatable :: string_value
    type(json_value), pointer :: array_items(:) => null()
    integer :: array_len = 0
    type(json_object_entry), pointer :: object_entries(:) => null()
    integer :: object_len = 0
  end type json_value

  type :: json_object_entry
    character(len=:), allocatable :: key
    type(json_value), pointer :: value => null()
  end type json_object_entry

  type :: parser_t
    character(len=:), allocatable :: text
    integer :: pos = 1
  end type parser_t

contains

  recursive subroutine json_free_inplace(value)
    type(json_value), intent(inout) :: value
    integer :: i
    if (value%value_type == JSON_STRING) then
      if (allocated(value%string_value)) deallocate(value%string_value)
    else if (value%value_type == JSON_ARRAY) then
      if (associated(value%array_items)) then
        do i = 1, value%array_len
          call json_free_inplace(value%array_items(i))
        end do
        deallocate(value%array_items)
      end if
    else if (value%value_type == JSON_OBJECT) then
      if (associated(value%object_entries)) then
        do i = 1, value%object_len
          if (allocated(value%object_entries(i)%key)) &
            deallocate(value%object_entries(i)%key)
          if (associated(value%object_entries(i)%value)) then
            call json_free(value%object_entries(i)%value)
          end if
        end do
        deallocate(value%object_entries)
      end if
    end if
    value%value_type = JSON_NULL
    value%array_len = 0
    value%object_len = 0
    value%array_items => null()
    value%object_entries => null()
  end subroutine json_free_inplace

  recursive subroutine json_free(value)
    type(json_value), pointer, intent(inout) :: value
    if (.not. associated(value)) return
    call json_free_inplace(value)
    deallocate(value)
    value => null()
  end subroutine json_free

  function json_object_get(obj, key) result(val)
    type(json_value), intent(in) :: obj
    character(len=*), intent(in) :: key
    type(json_value), pointer :: val
    integer :: i
    val => null()
    if (obj%value_type /= JSON_OBJECT) return
    if (.not. associated(obj%object_entries)) return
    do i = 1, obj%object_len
      if (obj%object_entries(i)%key == key) then
        val => obj%object_entries(i)%value
        return
      end if
    end do
  end function json_object_get

  subroutine skip_ws(p)
    type(parser_t), intent(inout) :: p
    do while (p%pos <= len(p%text))
      if (.not. is_space(p%text(p%pos:p%pos))) exit
      p%pos = p%pos + 1
    end do
  end subroutine skip_ws

  logical function peek(p, c) result(ok)
    type(parser_t), intent(in) :: p
    character(len=1), intent(in) :: c
    ok = (p%pos <= len(p%text) .and. p%text(p%pos:p%pos) == c)
  end function peek

  logical function expect(p, c) result(ok)
    type(parser_t), intent(inout) :: p
    character(len=1), intent(in) :: c
    call skip_ws(p)
    ok = peek(p, c)
    if (ok) p%pos = p%pos + 1
  end function expect

  recursive function parse_value(p, ok) result(val)
    type(parser_t), intent(inout) :: p
    logical, intent(out) :: ok
    type(json_value), pointer :: val
    character(len=1) :: c
    character(len=:), allocatable :: s
    ok = .false.
    val => null()
    call skip_ws(p)
    if (p%pos > len(p%text)) return
    c = p%text(p%pos:p%pos)
    if (c == '{') then
      val => parse_object(p, ok)
      return
    end if
    if (c == '[') then
      val => parse_array(p, ok)
      return
    end if
    if (c == '"') then
      s = parse_string(p, ok)
      if (.not. ok) return
      allocate(val)
      val%value_type = JSON_STRING
      val%string_value = s
      return
    end if
    if (c == 't' .and. p%pos + 3 <= len(p%text) .and. p%text(p%pos:p%pos+3) == 'true') then
      p%pos = p%pos + 4
      allocate(val)
      val%value_type = JSON_BOOL
      val%bool_value = .true.
      ok = .true.
      return
    end if
    if (c == 'f' .and. p%pos + 4 <= len(p%text) .and. p%text(p%pos:p%pos+4) == 'false') then
      p%pos = p%pos + 5
      allocate(val)
      val%value_type = JSON_BOOL
      val%bool_value = .false.
      ok = .true.
      return
    end if
    if (c == 'n' .and. p%pos + 3 <= len(p%text) .and. p%text(p%pos:p%pos+3) == 'null') then
      p%pos = p%pos + 4
      allocate(val)
      val%value_type = JSON_NULL
      ok = .true.
      return
    end if
    if (c == '-' .or. is_digit(c)) then
      val => parse_number(p, ok)
      return
    end if
  end function parse_value

  function parse_string(p, ok) result(out)
    type(parser_t), intent(inout) :: p
    logical, intent(out) :: ok
    character(len=:), allocatable :: out
    character(len=1) :: c, esc
    character(len=4) :: hex
    integer :: code, ios
    ok = .false.
    out = ''
    if (.not. expect(p, '"')) return
    do while (p%pos <= len(p%text))
      c = p%text(p%pos:p%pos)
      p%pos = p%pos + 1
      if (c == '"') then
        ok = .true.
        return
      end if
      if (c == '\') then
        if (p%pos > len(p%text)) return
        esc = p%text(p%pos:p%pos)
        p%pos = p%pos + 1
        select case (esc)
        case ('"', '\', '/')
          out = out // esc
        case ('b')
          out = out // achar(8)
        case ('f')
          out = out // achar(12)
        case ('n')
          out = out // achar(10)
        case ('r')
          out = out // achar(13)
        case ('t')
          out = out // achar(9)
        case ('u')
          if (p%pos + 3 > len(p%text)) return
          hex = p%text(p%pos:p%pos+3)
          p%pos = p%pos + 4
          read(hex, '(Z4)', iostat=ios) code
          if (ios /= 0) return
          out = out // achar(iand(code, 255))
        case default
          return
        end select
      else
        out = out // c
      end if
    end do
  end function parse_string

  function parse_number(p, ok) result(val)
    type(parser_t), intent(inout) :: p
    logical, intent(out) :: ok
    type(json_value), pointer :: val
    integer :: start_pos, ios
    character(len=:), allocatable :: raw
    real(kind=kind(1.0d0)) :: num
    ok = .false.
    val => null()
    start_pos = p%pos
    if (peek(p, '-')) p%pos = p%pos + 1
    do while (p%pos <= len(p%text) .and. is_digit(p%text(p%pos:p%pos)))
      p%pos = p%pos + 1
    end do
    if (peek(p, '.')) then
      p%pos = p%pos + 1
      do while (p%pos <= len(p%text) .and. is_digit(p%text(p%pos:p%pos)))
        p%pos = p%pos + 1
      end do
    end if
    if (p%pos <= len(p%text) .and. &
        (p%text(p%pos:p%pos) == 'e' .or. p%text(p%pos:p%pos) == 'E')) then
      p%pos = p%pos + 1
      if (peek(p, '+') .or. peek(p, '-')) p%pos = p%pos + 1
      do while (p%pos <= len(p%text) .and. is_digit(p%text(p%pos:p%pos)))
        p%pos = p%pos + 1
      end do
    end if
    raw = p%text(start_pos:p%pos-1)
    read(raw, *, iostat=ios) num
    if (ios /= 0) return
    allocate(val)
    val%value_type = JSON_NUMBER
    val%number_value = num
    ok = .true.
  end function parse_number

  recursive function parse_array(p, ok) result(val)
    type(parser_t), intent(inout) :: p
    logical, intent(out) :: ok
    type(json_value), pointer :: val
    type(json_value), pointer :: item
    type(json_value), pointer :: tmp(:)
    integer :: cap, i
    ok = .false.
    val => null()
    if (.not. expect(p, '[')) return
    allocate(val)
    val%value_type = JSON_ARRAY
    val%array_len = 0
    call skip_ws(p)
    if (peek(p, ']')) then
      p%pos = p%pos + 1
      ok = .true.
      return
    end if
    cap = 0
    do
      item => parse_value(p, ok)
      if (.not. ok .or. .not. associated(item)) then
        call json_free(val)
        return
      end if
      if (val%array_len >= cap) then
        if (cap == 0) then
          cap = 4
        else
          cap = cap * 2
        end if
        allocate(tmp(cap))
        do i = 1, val%array_len
          tmp(i) = val%array_items(i)
        end do
        if (associated(val%array_items)) deallocate(val%array_items)
        val%array_items => tmp
      end if
      val%array_len = val%array_len + 1
      val%array_items(val%array_len) = item
      ! item was a heap root; components moved via assignment — free shell
      deallocate(item)
      call skip_ws(p)
      if (peek(p, ']')) then
        p%pos = p%pos + 1
        ok = .true.
        return
      end if
      if (.not. expect(p, ',')) then
        call json_free(val)
        ok = .false.
        return
      end if
    end do
  end function parse_array

  recursive function parse_object(p, ok) result(val)
    type(parser_t), intent(inout) :: p
    logical, intent(out) :: ok
    type(json_value), pointer :: val
    type(json_value), pointer :: value
    type(json_object_entry), pointer :: tmp(:)
    character(len=:), allocatable :: key
    integer :: cap, i
    ok = .false.
    val => null()
    if (.not. expect(p, '{')) return
    allocate(val)
    val%value_type = JSON_OBJECT
    val%object_len = 0
    call skip_ws(p)
    if (peek(p, '}')) then
      p%pos = p%pos + 1
      ok = .true.
      return
    end if
    cap = 0
    do
      call skip_ws(p)
      key = parse_string(p, ok)
      if (.not. ok) then
        call json_free(val)
        return
      end if
      call skip_ws(p)
      if (.not. expect(p, ':')) then
        call json_free(val)
        ok = .false.
        return
      end if
      value => parse_value(p, ok)
      if (.not. ok .or. .not. associated(value)) then
        call json_free(val)
        ok = .false.
        return
      end if
      if (val%object_len >= cap) then
        if (cap == 0) then
          cap = 4
        else
          cap = cap * 2
        end if
        allocate(tmp(cap))
        do i = 1, val%object_len
          tmp(i)%key = val%object_entries(i)%key
          tmp(i)%value => val%object_entries(i)%value
        end do
        if (associated(val%object_entries)) deallocate(val%object_entries)
        val%object_entries => tmp
      end if
      val%object_len = val%object_len + 1
      val%object_entries(val%object_len)%key = key
      val%object_entries(val%object_len)%value => value
      call skip_ws(p)
      if (peek(p, '}')) then
        p%pos = p%pos + 1
        ok = .true.
        return
      end if
      if (.not. expect(p, ',')) then
        call json_free(val)
        ok = .false.
        return
      end if
    end do
  end function parse_object

  function json_parse(text) result(val)
    character(len=*), intent(in) :: text
    type(json_value), pointer :: val
    type(parser_t) :: p
    logical :: ok
    p%text = text
    p%pos = 1
    val => parse_value(p, ok)
    if (.not. ok .or. .not. associated(val)) then
      val => null()
      return
    end if
    call skip_ws(p)
    if (p%pos <= len(p%text)) then
      call json_free(val)
      return
    end if
  end function json_parse

end module wl_json
