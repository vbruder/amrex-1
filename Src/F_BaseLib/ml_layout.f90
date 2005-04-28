module ml_layout_module

  use layout_module
  use multifab_module
  use ml_boxarray_module

  implicit none

  type ml_layout
     integer :: dim = 0
     integer :: nlevel = 0
     type(ml_boxarray) :: mba
     type(layout)   , pointer ::    la(:) => Null()
     type(lmultifab), pointer ::  mask(:) => Null() ! cell-centered mask
     logical        , pointer :: pmask(:) => Null() ! periodic mask
  end type ml_layout

  interface destroy
     module procedure ml_layout_destroy
  end interface

  interface operator(.eq.)
     module procedure ml_layout_equal
  end interface
  interface operator(.ne.)
     module procedure ml_layout_not_equal
  end interface

contains

  function ml_layout_equal(mla1, mla2) result(r)
    logical :: r
    type(ml_layout), intent(in) :: mla1, mla2
    r = associated(mla1%la, mla2%la)
  end function ml_layout_equal
  
  function ml_layout_not_equal(mla1, mla2) result(r)
    logical :: r
    type(ml_layout), intent(in) :: mla1, mla2
    r = .not. associated(mla1%la, mla2%la)
  end function ml_layout_not_equal

  function ml_layout_get_layout(mla, n) result(r)
    type(layout) :: r
    type(ml_layout), intent(in) :: mla
    integer, intent(in) :: n
    r = mla%la(n)
  end function ml_layout_get_layout

  function ml_layout_get_pd(mla, n) result(r)
    type(box) :: r
    type(ml_layout), intent(in) :: mla
    integer, intent(in) :: n
    r = ml_boxarray_get_pd(mla%mba, n)
  end function ml_layout_get_pd

  subroutine ml_layout_build(mla, mba, pmask)
    type(ml_layout), intent(inout) :: mla
    type(ml_boxarray), intent(in) :: mba
    logical, optional :: pmask(:)

    type(boxarray) :: bac
    integer :: n
    logical :: lpmask(mba%dim)

    lpmask = .false.; if (present(pmask)) lpmask = pmask
    allocate(mla%pmask(mba%dim))
    mla%pmask  = lpmask

    mla%nlevel = mba%nlevel
    mla%dim    = mba%dim
    call copy(mla%mba, mba)
    allocate(mla%la(mla%nlevel))
    allocate(mla%mask(mla%nlevel-1))
    call build(mla%la(1), mba%bas(1),pmask=lpmask)
    do n = 2, mba%nlevel
       call layout_build_pn(mla%la(n), mla%la(n-1), mba%bas(n), mba%rr(n-1,:))
    end do
    do n = mba%nlevel-1,  1, -1
       call lmultifab_build(mla%mask(n), mla%la(n), nc = 1, ng = 0)
       call setval(mla%mask(n), val = .TRUE.)
       call copy(bac, mba%bas(n+1))
       call boxarray_coarsen(bac, mba%rr(n,:))
       call setval(mla%mask(n), .false., bac)
       call destroy(bac)
    end do
  end subroutine ml_layout_build

  subroutine ml_layout_destroy(mla)
    type(ml_layout), intent(inout) :: mla
    integer :: n
    do n = 1, mla%nlevel-1
       call destroy(mla%mask(n))
    end do
    call destroy(mla%mba)
    do n = 1, mla%nlevel
       call destroy(mla%la(n))
    end do
    deallocate(mla%la, mla%mask)
    mla%dim = 0
    mla%nlevel = 0
    deallocate(mla%pmask)
  end subroutine ml_layout_destroy

end module ml_layout_module
