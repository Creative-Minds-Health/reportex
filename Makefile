#!/bin/bash

.PHONY: deps
compile:
	# @rm -rf _build
	mix compile

run:
	iex --name reportex@127.0.0.1 -S mix
