import { ApiKeyStamper } from "@turnkey/api-key-stamper";
import type { ApiCredentials, TurnkeySDKClientConfig, TurnkeySDKServerConfig, TurnkeyProxyHandlerConfig } from "./__types__/base";
import { TurnkeySDKClientBase } from "./__generated__/sdk-client-base";
import type { RequestHandler } from "express";
import type { NextApiHandler } from "./__types__/base";
export declare class TurnkeyServerSDK {
    config: TurnkeySDKServerConfig;
    protected stamper: ApiKeyStamper | undefined;
    constructor(config: TurnkeySDKServerConfig);
    apiClient: (apiCredentials?: ApiCredentials) => TurnkeyApiClient;
    apiProxy: (methodName: string, params: any[]) => Promise<any>;
    expressProxyHandler: (config: TurnkeyProxyHandlerConfig) => RequestHandler;
    nextProxyHandler: (config: TurnkeyProxyHandlerConfig) => NextApiHandler;
}
export declare class TurnkeyServerClient extends TurnkeySDKClientBase {
    constructor(config: TurnkeySDKClientConfig);
    [methodName: string]: any;
}
export declare class TurnkeyApiClient extends TurnkeyServerClient {
    constructor(config: TurnkeySDKClientConfig);
}
//# sourceMappingURL=sdk-client.d.ts.map