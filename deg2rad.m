## Copyright (C) 2003 Stefan Burger
##
## This file is part of Octave.
##
## Octave is free software; you can redistribute it and/or modify it
## under the terms of the GNU General Public License as published by the
## Free Software Foundation; either version 2, or (at your option) any
## later version.
##
## Octave is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
## FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
## for more details.
##
## You should have received a copy of the GNU General Public License
## along with Octave; see the file COPYING.  If not, write to the Free
## Software Foundation, 59 Temple Place, Suite 330, Boston, MA 02111 USA.

## -*- texinfo -*-
## @deftypefn {Function File} {} deg2rad (@var{angle_d})
## Converts an anglular value in degrees @var{angle_d} to an angular value
## in radians.
## Input can be scalar, vector or a matrix.
## Conversion is done elementwise on the input.
## The returned value is of the same size as the input.
## @end deftypefn
## @seealso{rad2deg}

## Author: Stefan Burger <Stefan.Burger@stud.tu-muenchen.de>
## Description: converts angles degrees to radians.

function angle_r = deg2rad (angle_d)

  if (nargin != 1)
    usage("deg2rad (angle_d)");
  endif

  angle_r = angle_d * (pi/180);

endfunction
