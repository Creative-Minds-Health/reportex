#!/bin/bash

.PHONY: deps
compile:
	# @rm -rf _build
	rm -rf _build/dev/lib/xlsx/priv/
	mix compile
	mkdir -p _build/dev/lib/xlsx/priv/
	cp -R apps/xlsx/lib/xlsx/priv/* _build/dev/lib/xlsx/priv/

run:
	iex --name reportex@127.0.0.1 -S mix
