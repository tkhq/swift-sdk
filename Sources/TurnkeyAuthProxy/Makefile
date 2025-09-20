.PHONY: generate authproxy_client_types clean format

generate: authproxy_client_types authproxy_client format

authproxy_client_types:
	swift run swift-openapi-generator generate \
	--output-directory Generated \
	--config Resources/openapi-generator-config.yaml Resources/auth_proxy.yaml

authproxy_client:
	sourcery --sources Generated \
	--output Public/AuthProxyClient.swift \
	--templates Resources/Templates/AuthProxyClient.stencil \
	$(if $(WATCH),--watch,)

format:
	swift-format . -i -r
