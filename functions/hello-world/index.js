import { AssumeRoleWithWebIdentityCommand, STSClient } from "@aws-sdk/client-sts";
import * as functions from "@google-cloud/functions-framework";
import { GoogleAuth } from "google-auth-library";
import { randomUUID } from "node:crypto";
import * as winston from "winston";

const logger = winston.createLogger({
  level: "info",
  format: winston.format.json(),
  transports: [new winston.transports.Console()],
});

export const stsClient = new STSClient();
const auth = new GoogleAuth();

const getToken = async () => {
  const idTokenClient = await auth.getIdTokenClient(process.env.AUDIENCE);
  const token = await idTokenClient.idTokenProvider.fetchIdToken(process.env.AUDIENCE);
  return token;
};

functions.http("helloHttp", async (_req, res) => {
  logger.info("Running function...");

  const token = await getToken();
  logger.info("Received oidc token", { token });

  const input = {
    RoleArn: process.env.IAM_ROLE_ARN,
    RoleSessionName: randomUUID(),
    WebIdentityToken: token,
    DurationSeconds: 900,
  };
  const command = new AssumeRoleWithWebIdentityCommand(input);
  const response = await stsClient.send(command);

  res.setHeaders(
    new Headers({
      "Content-Type": "application/json",
    })
  );
  res.send(JSON.stringify(response));
});
