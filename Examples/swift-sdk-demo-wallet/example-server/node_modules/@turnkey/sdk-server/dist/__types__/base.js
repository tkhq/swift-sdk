'use strict';

exports.MethodType = void 0;
(function (MethodType) {
    MethodType[MethodType["Get"] = 0] = "Get";
    MethodType[MethodType["List"] = 1] = "List";
    MethodType[MethodType["Command"] = 2] = "Command";
})(exports.MethodType || (exports.MethodType = {}));
class TurnkeyRequestError extends Error {
    constructor(input) {
        let turnkeyErrorMessage = `Turnkey error ${input.code}: ${input.message}`;
        if (input.details != null) {
            turnkeyErrorMessage += ` (Details: ${JSON.stringify(input.details)})`;
        }
        super(turnkeyErrorMessage);
        this.name = "TurnkeyRequestError";
        this.details = input.details ?? null;
        this.code = input.code;
    }
}
exports.FilterType = void 0;
(function (FilterType) {
    FilterType["Email"] = "EMAIL";
    FilterType["PhoneNumber"] = "PHONE_NUMBER";
    FilterType["OidcToken"] = "OIDC_TOKEN";
    FilterType["PublicKey"] = "PUBLIC_KEY";
})(exports.FilterType || (exports.FilterType = {}));

exports.TurnkeyRequestError = TurnkeyRequestError;
//# sourceMappingURL=base.js.map
