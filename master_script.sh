#!/bin/bash
#emacs: -*- mode: shell-script; c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t -*- 
#ex: set sts=4 ts=4 sw=4 noet:
set -eu
subject=$1
run0=1
listen=1

CMD=
for run in `seq $run0 10`; do
	echo "======================================="
	echo "I: Subject $subject run ${run}"
	$CMD octave -q --eval "RET_localizer('$subject', $run, $listen)"
done
