.PHONY: generate turnkey_client_types turnkey_client clean format

generate: turnkey_client_types turnkey_client clean format

turnkey_client_types:
	swift run swift-openapi-generator generate \
	--output-directory Sources/TurnkeySDK/Generated \
	--config Sources/TurnkeySDK/openapi-generator-config.yaml Sources/TurnkeySDK/openapi.yaml

turnkey_client:
	sourcery --sources Sources/TurnkeySDK/Generated \
	--output Sources/TurnkeySDK/TurnkeyClient.generated.swift \
	--templates templates/TurnkeyClient.stencil \
	$(if $(WATCH),--watch,)

clean:
	rm -rf Sources/TurnkeySDK/Generated

test:
	make clean
	swift test

format:
	swift-format Tests Sources -i -r

WATCH ?=