MAKEFLAGS += --warn-undefined-variables
SHELL := /bin/bash
.EXPORT_ALL_VARIABLES:
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.SILENT:

all: test-scripts

.PHONY: test-scripts
test-scripts:
	# Checking for syntax errors
	for SCRIPT in Scripts/*.sh; do bash -n $$SCRIPT; done

	echo "Check bashisms";
	find ./Scripts -name '*.sh' -exec docker run --rm -it -v "$(PWD):$(PWD)" -w "$(PWD)" cmd.cat/checkbashisms checkbashisms {} \;

	echo "Shell check";
	find ./Scripts -name '*.sh' -exec docker run --rm -it -v "$(PWD):$(PWD)" -w "$(PWD)" koalaman/shellcheck:stable {} \;
