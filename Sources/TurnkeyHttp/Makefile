.PHONY: generate turnkey_client clean format

generate: turnkey_client format

turnkey_client:
	swift ../../Scripts/ClientCodegen.swift

clean:
	rm -rf Public/TurnkeyClient+Public.swift Public/TurnkeyClient+AuthProxy.swift

format:
	swift-format . -i -r

WATCH ?=
