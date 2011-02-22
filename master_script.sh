#!/bin/bash
#emacs: -*- mode: shell-script; c-basic-offset: 4; tab-width: 4; indent-tabs-mode: t -*- 
#ex: set sts=4 ts=4 sw=4 noet:

run=0
CMD=
for s in {1..3}; do
	run=$(($run+1))
	echo "Run ${run} - wedges"
	$CMD octave RET_localizerWEDGES.m
	run=$(($run+1))
	echo "Run ${run} - wedges"
	$CMD octave RET_localizerWEDGES.m
	run=$(($run+1))
	if [ $run -gt 10 ]; then
		echo "Exiting"
        break
	fi
	echo "Run ${run} - ring"
	$CMD octave RET_localizerRING.m
	run=$(($run+1))
	echo "Run ${run} - ring"
	$CMD octave RET_localizerRING.m
done
