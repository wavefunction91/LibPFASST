!--------------------------------------------------------------------------------
! Copyright (c) 2017, Brandon Krull.  All rights reserved.
!--------------------------------------------------------------------------------
! MODULE: factory
!
!> @author
!> Brandon Krull, Berkeley Lab
!
! Description:
!> This module defines the (previously encap) factory which defines
!! the time-dependent Kohn-Sham equations or simpler model time-dependent problems
module factory
  use pf_mod_dtype

  implicit none

  type, extends(pf_factory_t) :: zndarray_factory
  contains
     procedure :: create_single => zndarray_create_single
     procedure :: create_array => zndarray_create_array
     procedure :: destroy_single => zndarray_destroy_single
     procedure :: destroy_array => zndarray_destroy_array
  end type zndarray_factory

  type, extends(pf_encap_t) :: zndarray
    integer :: dim
    complex(pfdp), allocatable :: array(:,:), y(:,:)
  contains
    procedure :: setval => zndarray_setval
    procedure :: copy => zndarray_copy
    procedure :: norm => zndarray_norm
    procedure :: pack => zndarray_pack
    procedure :: unpack => zndarray_unpack
    procedure :: axpy => zndarray_axpy
    procedure :: eprint => zndarray_eprint
    procedure :: write_to_disk
  end type zndarray

  contains

  function cast_as_zndarray(encap_polymorph) result(zndarray_obj)
    class(pf_encap_t), intent(in), target :: encap_polymorph
    type(zndarray), pointer :: zndarray_obj

    select type(encap_polymorph)
    type is (zndarray)
       zndarray_obj => encap_polymorph
    end select
  end function cast_as_zndarray

  !> Allocates complex ndarray
  subroutine zndarray_build(encap, dim)
    class(pf_encap_t), intent(inout) :: encap
    integer, intent(in) ::  dim

    type(zndarray), pointer :: zndarray_obj

    zndarray_obj => cast_as_zndarray(encap)

    allocate(zndarray_obj%array(dim, dim))
    allocate(zndarray_obj%y(dim, dim))

    zndarray_obj%dim = dim
    zndarray_obj%array(:,:) = cmplx(0.0, 0.0,pfdp)
    zndarray_obj%y(:,:) = cmplx(0.0, 0.0,pfdp)

    nullify(zndarray_obj)
  end subroutine zndarray_build

  subroutine zndarray_destroy(encap)
    class(pf_encap_t), intent(inout) :: encap
    type(zndarray), pointer :: zndarray_obj

    zndarray_obj => cast_as_zndarray(encap)

    deallocate(zndarray_obj%array)
    deallocate(zndarray_obj%y)
    nullify(zndarray_obj)

  end subroutine zndarray_destroy

  !> Wrapper routine for allocation of a single zndarray type array
  subroutine zndarray_create_single(this, x, level, shape)
    class(zndarray_factory), intent(inout) :: this
    class(pf_encap_t), intent(inout), allocatable :: x
    integer, intent(in) :: level, shape(:)

    allocate(zndarray::x)
    call zndarray_build(x, shape(1))

  end subroutine zndarray_create_single

  !> Wrapper routine for looped allocation of many zndarray type arrays
  subroutine zndarray_create_array(this, x, n, level, shape)
    class(zndarray_factory), intent(inout) :: this
    class(pf_encap_t), intent(inout), allocatable :: x(:)
    integer, intent(in) :: n, level, shape(:)
    integer :: i

    allocate(zndarray::x(n))
    do i = 1, n
       call zndarray_build(x(i), shape(1))
    end do

  end subroutine zndarray_create_array

  subroutine zndarray_destroy_single(this, x, level, shape)
    class(zndarray_factory), intent(inout) :: this
    class(pf_encap_t), intent(inout) :: x
    integer, intent(in) :: level, shape(:)
    class(zndarray), pointer :: zndarray_obj

    zndarray_obj => cast_as_zndarray(x)
    deallocate(zndarray_obj%array)
    deallocate(zndarray_obj%y)

  end subroutine zndarray_destroy_single

  !> Wrapper routine for looped allocation of many zndarray type arrays
  subroutine zndarray_destroy_array(this, x, n, level, shape)
    class(zndarray_factory), intent(inout):: this
    class(pf_encap_t), intent(inout), pointer :: x(:)
    integer, intent(in) :: n, level, shape(:)
    class(zndarray), pointer :: zndarray_obj
    integer :: i

    do i = 1, n
      zndarray_obj => cast_as_zndarray(x(i))
      deallocate(zndarray_obj%array)
      deallocate(zndarray_obj%y)
    end do

!    deallocate(x)
  end subroutine zndarray_destroy_array

  !> Set solution value.
  subroutine zndarray_setval(this, val, flags)
    class(zndarray), intent(inout) :: this
    real(pfdp), intent(in) :: val
    integer, intent(in), optional :: flags
    complex(pfdp) :: zval

    zval = cmplx(val, 0.0, pfdp)
    if (present(flags)) then
       this%y =  zval
    else
       this%array =  zval
    endif
  end subroutine zndarray_setval

  !> Copy solution value.
  subroutine zndarray_copy(this, src, flags)
    class(zndarray), intent(inout) :: this
    class(pf_encap_t), intent(in) :: src
    integer, intent(in), optional :: flags
    class(zndarray), pointer :: zndarray_src

    zndarray_src => cast_as_zndarray(src)

    if (present(flags)) then
        this%array =  zndarray_src%array
    else
        this%y =  zndarray_src%y
    endif
  end subroutine zndarray_copy

  !> Pack solution q into a flat array.
  subroutine zndarray_pack(this, z)
    class(zndarray), intent(in) :: this
    real(pfdp), intent(out) :: z(:)
    integer :: nx,ny,nxny,i,j,ij
    nx=this%dim
    ny=this%dim
    nxny=nx*ny*2
    do j = 1,ny
       do i = 1,nx
          ij = 2*((j-1)*nx + i)
          z(ij-1) =  real(this%array(i,j))
          z(ij) = aimag(this%array(i,j))
       end do
    end do
    do j = 1,ny
       do i = 1,nx
          ij = 2*((j-1)*nx + i) + nxny
          z(ij-1) =  real(this%y(i,j))
          z(ij) = aimag(this%y(i,j))
       end do
    end do
  end subroutine zndarray_pack

  ! Unpack solution from a flat array.
  subroutine zndarray_unpack(this, z)
    class(zndarray), intent(inout) :: this
    real(pfdp), intent(in) :: z(:)
    integer :: nx,ny,nxny,i,j,ij
    nx=this%dim
    ny=this%dim
    nxny=nx*ny*2
    do j = 1,ny
       do i = 1,nx
          ij = 2*((j-1)*nx + i)
          this%array(i,j) = cmplx(z(ij-1), z(ij), pfdp)
       enddo
    enddo
    do j = 1,ny
       do i = 1,nx
          ij = 2*((j-1)*nx + i) + nxny
          this%y(i,j) = cmplx(z(ij-1), z(ij), pfdp)
      enddo
    enddo
  end subroutine zndarray_unpack

  ! Compute norm of solution
  function zndarray_norm(this) result (norm)
    class(zndarray), intent(in) :: this
    real(pfdp) :: norm
    norm = maxval(abs(this%array))
  end function zndarray_norm

  ! Compute y = a x + y where a is a scalar and x and y are solutions.
  subroutine zndarray_axpy(this, a, x, flags)
    class(zndarray), intent(inout) :: this
    class(pf_encap_t), intent(in) :: x
    real(pfdp), intent(in) :: a
    integer, intent(in), optional :: flags
    class(zndarray), pointer :: zndarray_obj

    zndarray_obj => cast_as_zndarray(x)
    this%array = a * zndarray_obj%array + this%array
  end subroutine zndarray_axpy

  subroutine zndarray_eprint(this)
    class(zndarray), intent(inout) :: this
    integer :: this_shape(2), i

    this_shape = shape(this%array)
    print*, 'omega'
    do i = 1, this_shape(1)-1
        print*, this%array(i,i+1)
    end do
    print*, 'y'
    do i = 1, this_shape(1)
       print*, this%y(i,i)
    end do
  end subroutine zndarray_eprint

  subroutine write_to_disk(this, filename)
    class(zndarray), intent(inout) :: this
    character(len=*), intent(in) :: filename

    open(unit=1, file=trim(filename), form='unformatted')
    write(1) this%y
    close(1)
  end subroutine write_to_disk

end module factory