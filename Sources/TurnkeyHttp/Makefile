.PHONY: generate turnkey_client_types turnkey_client clean format

generate: turnkey_client_types turnkey_client universal_components format

turnkey_client_types: public_types authproxy_types

public_types:
	swift run swift-openapi-generator generate \
		--output-directory Generated/Public \
		--config Resources/OpenApi/config.yaml \
		Resources/OpenApi/public-api.yaml


authproxy_types:
	swift run swift-openapi-generator generate \
		--output-directory Generated/AuthProxy \
		--config Resources/OpenApi/config.yaml \
		Resources/OpenApi/auth-proxy.yaml

turnkey_client: public_client authproxy_client

public_client:
	sourcery --sources Generated/Public \
		--output Public/TurnkeyClient+Public.swift \
		--templates Resources/Templates/Public/TurnkeyClient.stencil \
		$(if $(WATCH),--watch,)

authproxy_client:
	sourcery --sources Generated/AuthProxy \
		--output Public/TurnkeyClient+AuthProxy.swift \
		--templates Resources/Templates/AuthProxy/TurnkeyClient.stencil \
		$(if $(WATCH),--watch,)

universal_components:
	swift ../../Scripts/Codegen.swift

test:
	make clean
	swift test

format:
	swift-format . -i -r

WATCH ?=
