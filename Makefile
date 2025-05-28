.PHONY: generate turnkey_client_types turnkey_client clean format

generate: turnkey_client_types turnkey_client format

turnkey_client_types:
	swift run swift-openapi-generator generate \
	--output-directory Sources/TurnkeyHttp/Generated \
	--config Sources/TurnkeyHttp/Resources/openapi-generator-config.yaml Sources/TurnkeyHttp/Resources/openapi.yaml

turnkey_client:
	sourcery --sources Sources/TurnkeyHttp/Generated \
	--output Sources/TurnkeyHttp/Public/TurnkeyClient.swift \
	--templates Sources/TurnkeyHttp/Resources/Templates/TurnkeyClient.stencil \
	$(if $(WATCH),--watch,)

clean:
	rm -rf Sources/TurnkeyHttp/Generated

test:
	make clean
	swift test

format:
	swift-format Tests Sources -i -r

WATCH ?=