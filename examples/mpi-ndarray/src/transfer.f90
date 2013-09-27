!
! Copyright (c) 2012, Matthew Emmett and Michael Minion.  All rights reserved.
!

! Transfer (interpolate, restrict) routines.

module transfer
  use feval
  use probin
  implicit none
contains

  subroutine interp1(qF, qG, ctxF, ctxG)
    type(c_ptr), intent(in), value :: ctxF, ctxG
    real(pfdp),  intent(inout) :: qF(:), qG(:)

    type(work1),   pointer :: workF, workG
    complex(pfdp), pointer :: wkF(:), wkG(:)
    integer                :: nvarF, nvarG, xrat

    nvarF = size(qF)
    nvarG = size(qG)
    xrat  = nvarF / nvarG

    if (xrat == 1) then
       qF = qG
       return
    endif

    call c_f_pointer(ctxF, workF)
    call c_f_pointer(ctxG, workG)

    wkF => workF%wk
    wkG => workG%wk

    wkG = qG
    call fftw_execute_dft(workG%ffft, wkG, wkG)
    wkG = wkG / nvarG

    wkF = 0.0d0
    wkF(1:nvarG/2) = wkG(1:nvarG/2)
    wkF(nvarF-nvarG/2+2:nvarF) = wkG(nvarG/2+2:nvarG)

    call fftw_execute_dft(workF%ifft, wkF, wkF)

    qF = real(wkF)
  end subroutine interp1

  subroutine interpolate(qFp, qGp, levelF, ctxF, levelG, ctxG)
    type(c_ptr), intent(in), value :: qFp, qGp, ctxF, ctxG
    integer,     intent(in)        :: levelF, levelG

    real(pfdp),      pointer :: qF(:), qG(:), qF2(:,:), qG2(:,:)

    if (dim == 1) then
       qF => array1(qFp)
       qG => array1(qGp)

       call interp1(qF, qG, ctxF, ctxG)

    else if (problem == PROB_WAVE) then

       qF2 => array2(qFp)
       qG2 => array2(qGp)

       call interp1(qF2(:, 1), qG2(:, 1), ctxF, ctxG)
       call interp1(qF2(:, 2), qG2(:, 2), ctxF, ctxG)

    else if (problem == PROB_SHEAR) then

       print *, 'NOT IMPLEMENTED YET'

    end if
  end subroutine interpolate

  subroutine restrict(qFp, qGp, levelF, ctxF, levelG, ctxG)
    type(c_ptr), intent(in), value :: qFp, qGp, ctxF, ctxG
    integer,     intent(in)        :: levelF, levelG

    real(pfdp), pointer :: qF(:), qG(:), qF2(:,:), qG2(:,:)

    integer :: nvarF, nvarG, xrat

    if (problem == PROB_WAVE) then
       qF2 => array2(qFp)
       qG2 => array2(qGp)
       nvarF = size(qF2, 2)
       nvarG = size(qG2, 2)
       xrat  = nvarF / nvarG
       qG2 = qF2(::xrat,:)
    else if (problem == PROB_SHEAR) then
       qF2 => array2(qFp)
       qG2 => array2(qGp)
       nvarF = size(qF2, 2)
       nvarG = size(qG2, 2)
       xrat  = nvarF / nvarG
       qG2 = qF2(::xrat,::xrat)
    else
       qF => array1(qFp)
       qG => array1(qGp)
       nvarF = size(qF)
       nvarG = size(qG)
       xrat  = nvarF / nvarG
       qG = qF(::xrat)
    end if
  end subroutine restrict
end module transfer
