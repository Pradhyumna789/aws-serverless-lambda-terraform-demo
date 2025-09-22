import bcrypt from "bcryptjs";

export const handler = async (event) => {
  // event.body might be a string if POST
  const body = event.body ? JSON.parse(event.body) : {};

  // check both POST body and GET query string
  const password = body.password || (event.queryStringParameters && event.queryStringParameters.password);

  if (!password) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: "Password is required" }),
    };
  }

  const hashedPassword = await bcrypt.hash(password, 8);

  return {
    statusCode: 200,
    body: JSON.stringify({ hashedPassword }),
  };
};
