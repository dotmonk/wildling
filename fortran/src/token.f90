! Token expansion for wildling patterns.
module wl_token
  use iso_fortran_env, only: int64
  use wl_util
  implicit none
  private

  public :: token_t, token_init, token_free, token_count, token_get, int_pow

  type :: token_t
    character(len=:), allocatable :: src
    integer :: start_length = 1
    integer :: end_length = 1
    type(str_list) :: variants
    integer(int64) :: count = 0
  end type token_t

contains

  pure integer(int64) function int_pow(base, exp) result(r)
    integer(int64), intent(in) :: base
    integer, intent(in) :: exp
    integer :: i
    r = 1_int64
    do i = 1, exp
      r = r * base
    end do
  end function int_pow

  subroutine token_init(tok, src, start_length, end_length, variants)
    type(token_t), intent(out) :: tok
    character(len=*), intent(in) :: src
    integer, intent(in) :: start_length, end_length
    type(str_list), intent(inout) :: variants
    integer :: length_val
    integer(int64) :: nvar
    tok%src = src
    if (start_length >= 0) then
      tok%start_length = start_length
    else
      tok%start_length = 1
    end if
    if (end_length >= 0) then
      tok%end_length = end_length
    else
      tok%end_length = 1
    end if
    tok%variants = variants
    call str_list_init(variants)
    tok%count = 0_int64
    nvar = int(tok%variants%n, int64)
    do length_val = tok%start_length, tok%end_length
      tok%count = tok%count + int_pow(nvar, length_val)
    end do
  end subroutine token_init

  subroutine token_free(tok)
    type(token_t), intent(inout) :: tok
    if (allocated(tok%src)) deallocate(tok%src)
    call str_list_free(tok%variants)
    tok%count = 0
  end subroutine token_free

  pure integer(int64) function token_count(tok) result(n)
    type(token_t), intent(in) :: tok
    n = tok%count
  end function token_count

  function token_get(tok, index) result(out)
    type(token_t), intent(in) :: tok
    integer(int64), intent(in) :: index
    character(len=:), allocatable :: out
    integer(int64) :: index_with_offset, offset_count, nvar
    integer :: string_length, variant_index, i
    out = ''
    if (index > tok%count - 1_int64 .or. index < 0_int64) return
    if (index == 0_int64 .and. tok%start_length == 0) return

    index_with_offset = index
    string_length = tok%start_length
    nvar = int(tok%variants%n, int64)
    do string_length = tok%start_length, tok%end_length
      offset_count = int_pow(nvar, string_length)
      if (index_with_offset < offset_count) exit
      index_with_offset = index_with_offset - offset_count
    end do

    out = ''
    do i = 1, string_length
      if (tok%variants%n == 0) exit
      variant_index = int(mod(index_with_offset, nvar)) + 1
      index_with_offset = index_with_offset / nvar
      out = out // tok%variants%items(variant_index)%s
    end do
  end function token_get

end module wl_token
