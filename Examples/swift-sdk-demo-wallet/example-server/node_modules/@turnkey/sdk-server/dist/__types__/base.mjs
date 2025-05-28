var MethodType;
(function (MethodType) {
    MethodType[MethodType["Get"] = 0] = "Get";
    MethodType[MethodType["List"] = 1] = "List";
    MethodType[MethodType["Command"] = 2] = "Command";
})(MethodType || (MethodType = {}));
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
var FilterType;
(function (FilterType) {
    FilterType["Email"] = "EMAIL";
    FilterType["PhoneNumber"] = "PHONE_NUMBER";
    FilterType["OidcToken"] = "OIDC_TOKEN";
    FilterType["PublicKey"] = "PUBLIC_KEY";
})(FilterType || (FilterType = {}));

export { FilterType, MethodType, TurnkeyRequestError };
//# sourceMappingURL=base.mjs.map
