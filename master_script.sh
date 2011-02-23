#!/bin/bash
#emacs: -*- mode: shell-script; c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t -*- 
#ex: set sts=4 ts=4 sw=4 noet:
set -eu
if [ $# -ne 2 ]; then
	echo "Provide both subject and initial run (1)"
	exit 1
fi
subject=$1
run0=$2
listen=1

CMD=
for run in `seq $run0 10`; do
	echo "======================================="
	read -p "Proceed with subject $subject run ${run} ['n' to cancel]? " -n 1 proceed
	echo
	[ "$proceed" = 'n' ] &&	break
	{
		date
		$CMD octave -q --eval "RET_localizer('$subject', $run, $listen)"
	} 2>&1 | tee data/${subject}_$run.log
done
