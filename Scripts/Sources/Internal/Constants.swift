import Foundation

public enum CodegenConfig {
    public struct ActivityVersion {
        public let activityType: String
        public let intentKey: String
        public let resultKey: String

        public init(activityType: String, intentKey: String, resultKey: String) {
            self.activityType = activityType
            self.intentKey = intentKey
            self.resultKey = resultKey
        }
    }

    public static let versionedActivityTypes: [String: ActivityVersion] = [
        "ACTIVITY_TYPE_CREATE_AUTHENTICATORS": ActivityVersion(
            activityType: "ACTIVITY_TYPE_CREATE_AUTHENTICATORS_V2",
            intentKey: "v1CreateAuthenticatorsIntentV2",
            resultKey: "v1CreateAuthenticatorsResult"
        ),
        "ACTIVITY_TYPE_CREATE_API_KEYS": ActivityVersion(
            activityType: "ACTIVITY_TYPE_CREATE_API_KEYS_V2",
            intentKey: "v1CreateApiKeysIntentV2",
            resultKey: "v1CreateApiKeysResult"
        ),
        "ACTIVITY_TYPE_CREATE_POLICY": ActivityVersion(
            activityType: "ACTIVITY_TYPE_CREATE_POLICY_V3",
            intentKey: "v1CreatePolicyIntentV3",
            resultKey: "v1CreatePolicyResult"
        ),
        "ACTIVITY_TYPE_CREATE_PRIVATE_KEYS": ActivityVersion(
            activityType: "ACTIVITY_TYPE_CREATE_PRIVATE_KEYS_V2",
            intentKey: "v1CreatePrivateKeysIntentV2",
            resultKey: "v1CreatePrivateKeysResultV2"
        ),
        "ACTIVITY_TYPE_CREATE_SUB_ORGANIZATION": ActivityVersion(
            activityType: "ACTIVITY_TYPE_CREATE_SUB_ORGANIZATION_V8",
            intentKey: "v1CreateSubOrganizationIntentV8",
            resultKey: "v1CreateSubOrganizationResultV8"
        ),
        "ACTIVITY_TYPE_CREATE_USERS": ActivityVersion(
            activityType: "ACTIVITY_TYPE_CREATE_USERS_V4",
            intentKey: "v1CreateUsersIntentV4",
            resultKey: "v1CreateUsersResult"
        ),
        "ACTIVITY_TYPE_SIGN_RAW_PAYLOAD": ActivityVersion(
            activityType: "ACTIVITY_TYPE_SIGN_RAW_PAYLOAD_V2",
            intentKey: "v1SignRawPayloadIntentV2",
            resultKey: "v1SignRawPayloadResult"
        ),
        "ACTIVITY_TYPE_SIGN_TRANSACTION": ActivityVersion(
            activityType: "ACTIVITY_TYPE_SIGN_TRANSACTION_V2",
            intentKey: "v1SignTransactionIntentV2",
            resultKey: "v1SignTransactionResult"
        ),
        "ACTIVITY_TYPE_EMAIL_AUTH": ActivityVersion(
            activityType: "ACTIVITY_TYPE_EMAIL_AUTH_V3",
            intentKey: "v1EmailAuthIntentV3",
            resultKey: "v1EmailAuthResult"
        ),
        "ACTIVITY_TYPE_CREATE_READ_WRITE_SESSION": ActivityVersion(
            activityType: "ACTIVITY_TYPE_CREATE_READ_WRITE_SESSION_V2",
            intentKey: "v1CreateReadWriteSessionIntentV2",
            resultKey: "v1CreateReadWriteSessionResult"
        ),
        "ACTIVITY_TYPE_UPDATE_POLICY": ActivityVersion(
            activityType: "ACTIVITY_TYPE_UPDATE_POLICY_V2",
            intentKey: "v1UpdatePolicyIntentV2",
            resultKey: "v1UpdatePolicyResultV2"
        ),
        "ACTIVITY_TYPE_INIT_OTP_AUTH": ActivityVersion(
            activityType: "ACTIVITY_TYPE_INIT_OTP_AUTH_V3",
            intentKey: "v1InitOtpAuthIntentV3",
            resultKey: "v1InitOtpAuthResultV2"
        ),
        "ACTIVITY_TYPE_INIT_USER_EMAIL_RECOVERY": ActivityVersion(
            activityType: "ACTIVITY_TYPE_INIT_USER_EMAIL_RECOVERY_V2",
            intentKey: "v1InitUserEmailRecoveryIntentV2",
            resultKey: "v1InitUserEmailRecoveryResult"
        ),
        "ACTIVITY_TYPE_INIT_OTP": ActivityVersion(
            activityType: "ACTIVITY_TYPE_INIT_OTP_V3",
            intentKey: "v1InitOtpIntentV3",
            resultKey: "v1InitOtpResultV2"
        ),
        "ACTIVITY_TYPE_VERIFY_OTP": ActivityVersion(
            activityType: "ACTIVITY_TYPE_VERIFY_OTP_V2",
            intentKey: "v1VerifyOtpIntentV2",
            resultKey: "v1VerifyOtpResult"
        ),
        "ACTIVITY_TYPE_OTP_LOGIN": ActivityVersion(
            activityType: "ACTIVITY_TYPE_OTP_LOGIN_V2",
            intentKey: "v1OtpLoginIntentV2",
            resultKey: "v1OtpLoginResult"
        ),
        "ACTIVITY_TYPE_CREATE_OAUTH_PROVIDERS": ActivityVersion(
            activityType: "ACTIVITY_TYPE_CREATE_OAUTH_PROVIDERS_V2",
            intentKey: "v1CreateOauthProvidersIntentV2",
            resultKey: "v1CreateOauthProvidersResultV2"
        ),
    ]

    // Fields that should be treated as oneOf unions rather than both-optional.
    // Maps swagger type name to the list of field names that form the oneOf group.
    public static let oneOfFields: [String: [String]] = [
        "v1OauthProviderParamsV2": ["oidcToken", "oidcClaims"],
    ]
}
