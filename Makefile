#!/bin/bash
.PHONY: deps
npm:
	npm install
compile:
	# @rm -rf _build
	rm -rf _build/dev/lib/xlsx/priv/
	mix compile
	mkdir -p _build/dev/lib/xlsx/priv/
	cp -R apps/xlsx/lib/xlsx/priv/* _build/dev/lib/xlsx/priv/

run:
	iex --name reportex@127.0.0.1 -S mix

release:
	rm -rf _build
	MIX_ENV=prod mix release reportex
	mkdir -p _build/prod/rel/reportex/lib/xlsx-0.1.0/priv
	cp -R apps/xlsx/lib/xlsx/priv/* _build/prod/rel/reportex/lib/xlsx-0.1.0/priv

start:
	_build/prod/rel/reportex/bin/reportex start

daemon:
	_build/prod/rel/reportex/bin/reportex daemon

remote:
	_build/prod/rel/reportex/bin/reportex remote

stop:
	_build/prod/rel/reportex/bin/reportex stop

tail:
	tail -f _build/prod/rel/reportex/tmp/log/erlang.log.1
