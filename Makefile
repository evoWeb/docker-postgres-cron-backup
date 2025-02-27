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

	# Checking for bashisms (currently not failing, but only listing)
	SCRIPT="$$(which checkbashisms)";
	if [ -n "$$SCRIPT" ] && [ -x "$$SCRIPT" ]; then
		$$SCRIPT Scripts/*.sh || true;
	else
		echo "WARNING: skipping bashism test - you need to install checkbashism.";
	fi

	# Checking with shellcheck (currently not failing, but only listing)
	SCRIPT="$$(which shellcheck)";
	if [ -n "$$SCRIPT" ] && [ -x "$$SCRIPT" ]; then
		$$SCRIPT Scripts/*.sh || true;
	else
		echo "WARNING: skipping shellcheck test - you need to install shellcheck.";
	fi
