! String lists, dictionaries, and file helpers for wildling.
module wl_util
  implicit none
  private

  public :: string_t, str_list, dict_entry, dictionaries
  public :: str_list_init, str_list_free, str_list_push, str_list_join
  public :: dictionaries_init, dictionaries_free, dictionaries_set
  public :: dictionaries_get, dictionaries_has, dictionaries_names
  public :: read_file, rtrim_copy, int_to_str, try_parse_int
  public :: char_at, str_len, str_eq, str_starts, substr, concat2, concat3
  public :: is_digit, is_space, file_exists

  type :: string_t
    character(len=:), allocatable :: s
  end type string_t

  type :: str_list
    type(string_t), allocatable :: items(:)
    integer :: n = 0
  end type str_list

  type :: dict_entry
    character(len=:), allocatable :: name
    type(str_list) :: words
  end type dict_entry

  type :: dictionaries
    type(dict_entry), allocatable :: items(:)
    integer :: n = 0
  end type dictionaries

contains

  pure integer function str_len(s) result(n)
    character(len=*), intent(in) :: s
    n = len(s)
  end function str_len

  pure character(len=1) function char_at(s, i) result(c)
    character(len=*), intent(in) :: s
    integer, intent(in) :: i
    if (i < 1 .or. i > len(s)) then
      c = achar(0)
    else
      c = s(i:i)
    end if
  end function char_at

  pure logical function str_eq(a, b) result(ok)
    character(len=*), intent(in) :: a, b
    ok = (a == b)
  end function str_eq

  pure logical function str_starts(s, prefix) result(ok)
    character(len=*), intent(in) :: s, prefix
    integer :: n
    n = len(prefix)
    if (len(s) < n) then
      ok = .false.
    else
      ok = (s(1:n) == prefix)
    end if
  end function str_starts

  function substr(s, start, n) result(out)
    character(len=*), intent(in) :: s
    integer, intent(in) :: start, n
    character(len=:), allocatable :: out
    integer :: a, b, m
    if (n <= 0 .or. start > len(s) .or. start < 1) then
      out = ''
      return
    end if
    a = start
    m = min(n, len(s) - start + 1)
    b = a + m - 1
    out = s(a:b)
  end function substr

  function concat2(a, b) result(out)
    character(len=*), intent(in) :: a, b
    character(len=:), allocatable :: out
    out = a // b
  end function concat2

  function concat3(a, b, c) result(out)
    character(len=*), intent(in) :: a, b, c
    character(len=:), allocatable :: out
    out = a // b // c
  end function concat3

  pure logical function is_digit(c) result(ok)
    character(len=1), intent(in) :: c
    ok = (c >= '0' .and. c <= '9')
  end function is_digit

  pure logical function is_space(c) result(ok)
    character(len=1), intent(in) :: c
    ok = (c == ' ' .or. c == achar(9) .or. c == achar(10) .or. c == achar(13))
  end function is_space

  subroutine str_list_init(list)
    type(str_list), intent(out) :: list
    list%n = 0
    if (allocated(list%items)) deallocate(list%items)
  end subroutine str_list_init

  subroutine str_list_free(list)
    type(str_list), intent(inout) :: list
    integer :: i
    if (allocated(list%items)) then
      do i = 1, list%n
        if (allocated(list%items(i)%s)) deallocate(list%items(i)%s)
      end do
      deallocate(list%items)
    end if
    list%n = 0
  end subroutine str_list_free

  subroutine str_list_grow(list)
    type(str_list), intent(inout) :: list
    type(string_t), allocatable :: tmp(:)
    integer :: new_cap, i, old_cap
    old_cap = 0
    if (allocated(list%items)) old_cap = size(list%items)
    if (list%n < old_cap) return
    if (old_cap == 0) then
      new_cap = 8
    else
      new_cap = old_cap * 2
    end if
    allocate(tmp(new_cap))
    do i = 1, list%n
      tmp(i)%s = list%items(i)%s
    end do
    call move_alloc(tmp, list%items)
  end subroutine str_list_grow

  subroutine str_list_push(list, s)
    type(str_list), intent(inout) :: list
    character(len=*), intent(in) :: s
    call str_list_grow(list)
    list%n = list%n + 1
    list%items(list%n)%s = s
  end subroutine str_list_push

  function str_list_join(list, sep) result(out)
    type(str_list), intent(in) :: list
    character(len=*), intent(in) :: sep
    character(len=:), allocatable :: out
    integer :: i
    out = ''
    do i = 1, list%n
      if (i > 1) out = out // sep
      out = out // list%items(i)%s
    end do
  end function str_list_join

  subroutine dictionaries_init(dicts)
    type(dictionaries), intent(out) :: dicts
    dicts%n = 0
    if (allocated(dicts%items)) deallocate(dicts%items)
  end subroutine dictionaries_init

  subroutine dictionaries_free(dicts)
    type(dictionaries), intent(inout) :: dicts
    integer :: i
    if (allocated(dicts%items)) then
      do i = 1, dicts%n
        if (allocated(dicts%items(i)%name)) deallocate(dicts%items(i)%name)
        call str_list_free(dicts%items(i)%words)
      end do
      deallocate(dicts%items)
    end if
    dicts%n = 0
  end subroutine dictionaries_free

  subroutine dictionaries_grow(dicts)
    type(dictionaries), intent(inout) :: dicts
    type(dict_entry), allocatable :: tmp(:)
    integer :: new_cap, i, old_cap
    old_cap = 0
    if (allocated(dicts%items)) old_cap = size(dicts%items)
    if (dicts%n < old_cap) return
    if (old_cap == 0) then
      new_cap = 4
    else
      new_cap = old_cap * 2
    end if
    allocate(tmp(new_cap))
    do i = 1, dicts%n
      tmp(i)%name = dicts%items(i)%name
      tmp(i)%words = dicts%items(i)%words
    end do
    call move_alloc(tmp, dicts%items)
  end subroutine dictionaries_grow

  subroutine dictionaries_set(dicts, name, words)
    type(dictionaries), intent(inout) :: dicts
    character(len=*), intent(in) :: name
    type(str_list), intent(inout) :: words
    integer :: i
    do i = 1, dicts%n
      if (dicts%items(i)%name == name) then
        call str_list_free(dicts%items(i)%words)
        dicts%items(i)%words = words
        call str_list_init(words)
        return
      end if
    end do
    call dictionaries_grow(dicts)
    dicts%n = dicts%n + 1
    dicts%items(dicts%n)%name = name
    dicts%items(dicts%n)%words = words
    call str_list_init(words)
  end subroutine dictionaries_set

  function dictionaries_get(dicts, name) result(words)
    type(dictionaries), intent(in) :: dicts
    character(len=*), intent(in) :: name
    type(str_list) :: words
    integer :: i
    call str_list_init(words)
    do i = 1, dicts%n
      if (dicts%items(i)%name == name) then
        words = dicts%items(i)%words
        return
      end if
    end do
  end function dictionaries_get

  logical function dictionaries_has(dicts, name) result(ok)
    type(dictionaries), intent(in) :: dicts
    character(len=*), intent(in) :: name
    integer :: i
    ok = .false.
    do i = 1, dicts%n
      if (dicts%items(i)%name == name) then
        ok = .true.
        return
      end if
    end do
  end function dictionaries_has

  subroutine dictionaries_names(dicts, names)
    type(dictionaries), intent(in) :: dicts
    type(str_list), intent(out) :: names
    integer :: i
    call str_list_init(names)
    do i = 1, dicts%n
      call str_list_push(names, dicts%items(i)%name)
    end do
  end subroutine dictionaries_names

  function rtrim_copy(s) result(out)
    character(len=*), intent(in) :: s
    character(len=:), allocatable :: out
    integer :: n
    n = len(s)
    do while (n > 0)
      if (.not. is_space(s(n:n))) exit
      n = n - 1
    end do
    if (n <= 0) then
      out = ''
    else
      out = s(1:n)
    end if
  end function rtrim_copy

  function int_to_str(v) result(out)
    integer, intent(in) :: v
    character(len=:), allocatable :: out
    character(len=32) :: buf
    write(buf, '(I0)') v
    out = trim(buf)
  end function int_to_str

  logical function try_parse_int(s, v) result(ok)
    character(len=*), intent(in) :: s
    integer, intent(out) :: v
    integer :: ios
    ok = .false.
    v = -1
    if (len(s) == 0) return
    read(s, *, iostat=ios) v
    if (ios == 0) ok = .true.
  end function try_parse_int

  logical function file_exists(path) result(ok)
    character(len=*), intent(in) :: path
    integer :: unit, ios
    inquire(file=path, exist=ok)
    if (.not. ok) return
    open(newunit=unit, file=path, status='old', action='read', iostat=ios)
    if (ios /= 0) then
      ok = .false.
      return
    end if
    close(unit)
    ok = .true.
  end function file_exists

  function read_file(path, ok) result(content)
    character(len=*), intent(in) :: path
    logical, intent(out) :: ok
    character(len=:), allocatable :: content
    integer :: unit, ios, sz, nread
    character(len=1), allocatable :: buf(:)
    integer :: i
    ok = .false.
    content = ''
    open(newunit=unit, file=path, status='old', action='read', &
         access='stream', form='unformatted', iostat=ios)
    if (ios /= 0) return
    inquire(unit=unit, size=sz)
    if (sz < 0) then
      close(unit)
      return
    end if
    if (sz == 0) then
      content = ''
      close(unit)
      ok = .true.
      return
    end if
    allocate(buf(sz))
    read(unit, iostat=ios) buf
    nread = sz
    if (ios /= 0) then
      deallocate(buf)
      close(unit)
      return
    end if
    close(unit)
    if (allocated(content)) deallocate(content)
    allocate(character(len=nread) :: content)
    do i = 1, nread
      content(i:i) = buf(i)
    end do
    deallocate(buf)
    ok = .true.
  end function read_file

end module wl_util
