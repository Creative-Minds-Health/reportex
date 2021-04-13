#!/bin/bash
.PHONY: deps
npm:
	npm install
deps:
	rm -rf deps/
	mix deps.get
	cp features/elixlsx/font.ex deps/elixlsx/lib/elixlsx/style/font.ex
	cp features/elixlsx/xml_templates.ex deps/elixlsx/lib/elixlsx/xml_templates.ex
	mix deps.compile

compile:
	# @rm -rf _build
	rm -rf Mnesia*
	rm -rf _build/dev/lib/xlsx/priv/
	mix compile
	mkdir -p _build/dev/lib/xlsx/priv/
	cp -R apps/xlsx/lib/xlsx/priv/* _build/dev/lib/xlsx/priv/

run:
	iex --name master@127.0.0.1 -S mix

release:
	make deps
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
	tail -f -n 500 `find _build/prod/rel/reportex/tmp/log/erlang.log.* -type f -printf '%T+ %p\n' | sort -r | head -1  | tr -s ' ' | cut -d ' ' -f 2 `
