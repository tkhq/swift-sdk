import { type TurnkeyApiTypes } from "@turnkey/sdk-server";

export enum OtpType {
  Email = "OTP_TYPE_EMAIL",
  Sms = "OTP_TYPE_SMS",
}

export enum FilterType {
  Email = "EMAIL",
  PhoneNumber = "PHONE_NUMBER",
}

export type GetSubOrgIdParams = {
  filterType:
    | "NAME"
    | "USERNAME"
    | "EMAIL"
    | "PHONE_NUMBER"
    | "CREDENTIAL_ID"
    | "PUBLIC_KEY"
    | "OIDC_TOKEN";
  filterValue: string;
};

export type GetSubOrgIdResponse = {
  organizationId: string;
};

export type SendOtpParams = {
  otpType: "OTP_TYPE_EMAIL" | "OTP_TYPE_SMS";
  contact: string;
  userIdentifier: string;
};

export type SendOtpResponse = {
  otpId: string;
};

export type CreateSubOrgParams = {
  email: string;
  phone?: string;
  passkey?: {
    name?: string;
    challenge: string;
    attestation: Attestation;
  };
  apiKeys?: {
    apiKeyName: string;
    publicKey: string;
    curveType: ApiKeyCurveType;
    expirationSeconds?: string;
  }[];
};

export type CreateSubOrgResponse = {
  subOrganizationId: string;
};

export type VerifyOtpParams = {
  otpId: string;
  otpCode: string;
  otpType: OtpType;
  contact: string;
  publicKey: string;
  expirationSeconds: string;
};

export type VerifyOtpResponse = {
  token?: string;
};

export type Attestation = TurnkeyApiTypes["v1Attestation"];
export type ApiKeyCurveType = TurnkeyApiTypes["v1ApiKeyCurve"];
