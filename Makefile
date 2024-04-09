.PHONY: generate turnkey_client sourcery clean

generate: turnkey_client sourcery clean

turnkey_client:
	swift run swift-openapi-generator generate \
	--output-directory Sources/TurnkeySDK/Generated \
	--config Sources/TurnkeySDK/openapi-generator-config.yaml Sources/TurnkeySDK/openapi.yaml

sourcery:
	sourcery --sources Sources/TurnkeySDK/Generated \
	--output Sources/TurnkeySDK/TurnkeyClient.swift \
	--templates $(TEMPLATES) \
	$(if $(WATCH),--watch,)

clean:
	rm -rf Sources/TurnkeySDK/Generated

test:
	make clean
	swift test

TEMPLATES ?= TurnkeyClient.stencil
WATCH ?=