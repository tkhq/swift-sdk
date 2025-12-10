# Swift Demo Wallet Examples

This example shows how to build a native iOS wallet application with Turnkey, featuring authentication (OTP, OAuth, Passkeys) and wallet operations (message signing, transaction sending).

It contains two separate implementations:

- **without-backend** - Uses Turnkey's managed Auth Proxy to securely handle sign-up and login flows with origin enforcement and centralized configuration - no backend required. Your Swift app interacts directly with Turnkey.
- **with-backend** - Demonstrates how to run the same authentication flow through your own backend.

## Auth Proxy Highlights

- No need to host or maintain your own authentication backend. The Auth Proxy is a managed, multi-tenant service that handles signing and forwarding authentication requests.
- Proxy keys are HPKE-encrypted inside Turnkey's enclave and decrypted only in memory per request. Includes strict origin validation and CORS enforcement.
- Manage allowed origins, session lifetimes, email/SMS templates, and OAuth settings directly from the Turnkey Dashboard.
- The Swift app calls Auth Proxy endpoints directly - no backend endpoints needed for OTP, OAuth, or signup flows.

[Read more about Auth the Proxy](https://docs.turnkey.com/reference/auth-proxy)

## Custom Backend Highlights

You could:

- Store and retrieve user data associated with Turnkey sub-organizations.
- Add custom validations, rate limiting, and logging.
- Enable 2/2 signing patterns where your application is a co-signer.
