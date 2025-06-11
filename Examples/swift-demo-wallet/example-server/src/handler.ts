import { Request } from "express";
import dotenv from "dotenv";
import { DEFAULT_ETHEREUM_ACCOUNTS, Turnkey } from "@turnkey/sdk-server";
import { decodeJwt } from "./util.js";
import {
  CreateSubOrgParams,
  CreateSubOrgResponse,
  SendOtpParams,
  OtpType,
  FilterType,
  VerifyOtpResponse,
  VerifyOtpParams,
  SendOtpResponse,
  OAuthParams,
  OAuthResponse,
} from "./types.js";

dotenv.config();

export const turnkeyConfig = {
  apiBaseUrl: process.env.TURNKEY_API_URL ?? "",
  defaultOrganizationId: process.env.TURNKEY_ORGANIZATION_ID ?? "",
  apiPublicKey: process.env.TURNKEY_API_PUBLIC_KEY ?? "",
  apiPrivateKey: process.env.TURNKEY_API_PRIVATE_KEY ?? "",
};

const turnkey = new Turnkey(turnkeyConfig).apiClient();

export async function sendOtp(
  req: Request<{}, {}, SendOtpParams>
): Promise<SendOtpResponse> {
  const { otpType, contact, userIdentifier } = req.body;

  const sendOtpResponse = await turnkey.initOtp({
    otpType: otpType,
    contact: contact,
    smsCustomization: { template: "Your Turnkey Demo OTP is {{.OtpCode}}" },
    otpLength: 6,
    userIdentifier,
  });

  return {
    otpId: sendOtpResponse.otpId,
  };
}

export async function verifyOtp(
  req: Request<{}, {}, VerifyOtpParams>
): Promise<VerifyOtpResponse> {
  const { otpId, otpCode, otpType, contact, publicKey, expirationSeconds } =
    req.body;

  const verifyResponse = await turnkey.verifyOtp({
    otpId,
    otpCode,
    expirationSeconds,
  });

  let organizationId = turnkeyConfig.defaultOrganizationId;

  const { organizationIds } = await turnkey.getSubOrgIds({
    filterType:
      otpType === OtpType.Email ? FilterType.Email : FilterType.PhoneNumber,
    filterValue: contact,
  });

  if (organizationIds.length > 0) {
    organizationId = organizationIds[0];
  } else {
    const createSubOrgParams =
      otpType === OtpType.Email ? { email: contact } : { phone: contact };

    const subOrgResponse = await createSubOrg({
      body: createSubOrgParams,
    } as Request);
    organizationId = subOrgResponse.subOrganizationId;
  }

  const sessionResponse = await turnkey.otpLogin({
    organizationId,
    verificationToken: verifyResponse!.verificationToken,
    publicKey,
    expirationSeconds,
  });

  return { token: sessionResponse.session };
}

export async function createSubOrg(
  req: Request<{}, {}, CreateSubOrgParams>
): Promise<CreateSubOrgResponse> {
  const { email, phone, passkey, oauth, apiKeys } = req.body;

  const authenticators = passkey
    ? [
        {
          authenticatorName: "Passkey",
          challenge: passkey.challenge,
          attestation: passkey.attestation,
        },
      ]
    : [];

  const oauthProviders = oauth
    ? [
        {
          providerName: oauth.providerName,
          oidcToken: oauth.oidcToken,
        },
      ]
    : [];

  let userEmail = email;
  const userPhoneNumber = phone;

  const subOrganizationName = `Sub Org - ${new Date().toISOString()}`;

  const result = await turnkey.createSubOrganization({
    organizationId: turnkeyConfig.defaultOrganizationId,
    subOrganizationName,
    rootUsers: [
      {
        userName: "User",
        userEmail,
        userPhoneNumber,
        authenticators,
        oauthProviders: oauthProviders,
        apiKeys: apiKeys ?? [],
      },
    ],
    rootQuorumThreshold: 1,
    wallet: {
      walletName: "Default Wallet",
      accounts: DEFAULT_ETHEREUM_ACCOUNTS,
    },
  });

  return { subOrganizationId: result.subOrganizationId };
}

export async function oAuth(
  req: Request<{}, {}, OAuthParams>
): Promise<OAuthResponse> {
  const { publicKey, providerName, oidcToken, expirationSeconds } = req.body;

  let organizationId = turnkeyConfig.defaultOrganizationId;

  const { organizationIds } = await turnkey.getSubOrgIds({
    filterType: "OIDC_TOKEN",
    filterValue: oidcToken,
  });

  if (organizationIds.length > 0) {
    organizationId = organizationIds[0];
  } else {
    const createSubOrgParams = {
      oauth: {
        providerName,
        oidcToken,
      },
    };

    const subOrgResponse = await createSubOrg({
      body: createSubOrgParams,
    } as Request);
    organizationId = subOrgResponse.subOrganizationId;
  }

  const sessionResponse = await turnkey.oauthLogin({
    publicKey,
    organizationId,
    oidcToken,
    expirationSeconds,
  });

  return { token: sessionResponse.session };
}
