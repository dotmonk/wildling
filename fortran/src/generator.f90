! Single-pattern generator.
module wl_generator
  use iso_fortran_env, only: int64
  use wl_util
  use wl_token
  use wl_parse_pattern
  implicit none
  private

  public :: generator_t, generator_init, generator_free, generator_count, generator_get

  type :: generator_t
    character(len=:), allocatable :: source
    type(token_list) :: tokens
    integer(int64) :: count = 0
  end type generator_t

contains

  subroutine generator_init(gen, input_pattern, dicts)
    type(generator_t), intent(out) :: gen
    character(len=*), intent(in) :: input_pattern
    type(dictionaries), intent(in) :: dicts
    integer :: i
    gen%source = input_pattern
    call parse_pattern(input_pattern, dicts, gen%tokens)
    gen%count = 1_int64
    do i = 1, gen%tokens%n
      gen%count = gen%count * token_count(gen%tokens%items(i))
    end do
  end subroutine generator_init

  subroutine generator_free(gen)
    type(generator_t), intent(inout) :: gen
    if (allocated(gen%source)) deallocate(gen%source)
    call token_list_free(gen%tokens)
    gen%count = 0
  end subroutine generator_free

  pure integer(int64) function generator_count(gen) result(n)
    type(generator_t), intent(in) :: gen
    n = gen%count
  end function generator_count

  function generator_get(gen, index) result(out)
    type(generator_t), intent(in) :: gen
    integer(int64), intent(in) :: index
    character(len=:), allocatable :: out
    integer(int64) :: index_with_offset, tc
    integer :: i
    out = ''
    if (index > gen%count - 1_int64 .or. index < 0_int64) return
    index_with_offset = index
    do i = 1, gen%tokens%n
      tc = token_count(gen%tokens%items(i))
      out = out // token_get(gen%tokens%items(i), mod(index_with_offset, tc))
      index_with_offset = index_with_offset / tc
    end do
  end function generator_get

end module wl_generator
