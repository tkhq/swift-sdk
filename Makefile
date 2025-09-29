.PHONY: generate-all http authproxy format

generate-all: http authproxy

http:
	$(MAKE) -C Sources/TurnkeyHttp generate

authproxy:
	$(MAKE) -C Sources/TurnkeyAuthProxy generate

format:
	swift-format . -i -r

