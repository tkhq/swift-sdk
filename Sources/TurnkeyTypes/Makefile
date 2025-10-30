.PHONY: generate types format clean

generate: types format

types:
	swift ../../Scripts/Typegen.swift

format:
	swift-format Generated/ -i -r

clean:
	rm -rf Generated/*

.DEFAULT_GOAL := generate
