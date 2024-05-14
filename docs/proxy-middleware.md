# Prox yMiddleware

The [`ProxyMiddleware`](/Sources/Middleware/ProxyMiddleware.swift) is integrated into the TurnkeyClient through its initializer that accepts a proxy server URL. This setup is particularly useful for handling scenarios where direct authenticated requests are not feasible, such as during onboarding flows or when additional server-side processing is required before reaching Turnkey's backend.

Here's how you can initialize the TurnkeyClient with a proxy server URL:

```swift
import TurnkeySDK

// Initialize the TurnkeyClient with a proxy server URL
let turnkeyClient = TurnkeyClient(proxyURL: "https://your-proxy-server.com")
```

This initializer configures the TurnkeyClient to route all requests through the specified proxy server. The proxy server is then responsible for forwarding these requests to a backend capable of authenticating them using an API private key. After authentication, the proxy server forwards the requests to Turnkey's backend and relays the response back to the client.

This setup is especially useful for operations like:

- Email authentication/recovery
- Wallet import/export
- Sub-organization creation

## Important Notes

- **Response Matching**: It is crucial that the response from the developer's backend matches exactly with what would be expected from Turnkey's backend. Any discrepancy in the response format or data can cause the request to fail.
- **Security**: Ensure that the proxy server is secure and only accessible to authorized entities to prevent unauthorized access and data breaches.

## Conclusion

While `ProxyMiddleware` is not required, it provides a convenient way to send requests on behalf of unauthenticated users looking to perform
