! Multi-pattern wildling API.
module wl_wildling
  use iso_fortran_env, only: int64
  use wl_util
  use wl_generator
  implicit none
  private

  public :: WILDLING_VERSION
  public :: wildling_t, wildling_init, wildling_free
  public :: wildling_count, wildling_reset, wildling_next, wildling_get

  character(len=*), parameter :: WILDLING_VERSION = '2.0.4'

  type :: wildling_t
    type(generator_t), allocatable :: generators(:)
    integer :: ngen = 0
    integer(int64) :: pattern_count = 0
    integer(int64) :: internal_index = 0
  end type wildling_t

contains

  subroutine wildling_init(w, patterns, dicts)
    type(wildling_t), intent(out) :: w
    type(str_list), intent(in) :: patterns
    type(dictionaries), intent(in) :: dicts
    integer :: i
    w%ngen = 0
    w%pattern_count = 0
    w%internal_index = 0
    if (patterns%n == 0) return
    allocate(w%generators(patterns%n))
    do i = 1, patterns%n
      call generator_init(w%generators(i), patterns%items(i)%s, dicts)
      w%pattern_count = w%pattern_count + generator_count(w%generators(i))
      w%ngen = w%ngen + 1
    end do
  end subroutine wildling_init

  subroutine wildling_free(w)
    type(wildling_t), intent(inout) :: w
    integer :: i
    if (allocated(w%generators)) then
      do i = 1, w%ngen
        call generator_free(w%generators(i))
      end do
      deallocate(w%generators)
    end if
    w%ngen = 0
    w%pattern_count = 0
    w%internal_index = 0
  end subroutine wildling_free

  pure integer(int64) function wildling_count(w) result(n)
    type(wildling_t), intent(in) :: w
    n = w%pattern_count
  end function wildling_count

  subroutine wildling_reset(w)
    type(wildling_t), intent(inout) :: w
    w%internal_index = 0
  end subroutine wildling_reset

  logical function wildling_get(w, index, value) result(ok)
    type(wildling_t), intent(in) :: w
    integer(int64), intent(in) :: index
    character(len=:), allocatable, intent(out) :: value
    integer(int64) :: segment_index, pattern_index, gc
    integer :: i
    value = ''
    ok = .false.
    if (index > w%pattern_count - 1_int64 .or. index < 0_int64) return
    segment_index = 0
    do i = 1, w%ngen
      gc = generator_count(w%generators(i))
      pattern_index = index - segment_index
      if (pattern_index < gc) then
        value = generator_get(w%generators(i), pattern_index)
        ok = .true.
        return
      end if
      segment_index = segment_index + gc
    end do
  end function wildling_get

  logical function wildling_next(w, value) result(ok)
    type(wildling_t), intent(inout) :: w
    character(len=:), allocatable, intent(out) :: value
    value = ''
    ok = .false.
    if (w%internal_index == w%pattern_count) return
    w%internal_index = w%internal_index + 1
    ok = wildling_get(w, w%internal_index - 1_int64, value)
  end function wildling_next

end module wl_wildling
