.PHONY: generate turnkey_client_types turnkey_client clean format

generate: turnkey_client_types turnkey_client format

turnkey_client_types:
	swift run swift-openapi-generator generate \
	--output-directory Generated \
	--config Resources/openapi-generator-config.yaml Resources/openapi.yaml

turnkey_client:
	sourcery --sources Generated \
	--output Public/TurnkeyClient.swift \
	--templates Resources/Templates/TurnkeyClient.stencil \
	$(if $(WATCH),--watch,)

test:
	make clean
	swift test

format:
	swift-format . -i -r

WATCH ?=
