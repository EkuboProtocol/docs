import schemaJson from "../../data/ekubo-wallet-policy.schema.json?raw";

export function GET() {
  return new Response(schemaJson, {
    headers: {
      "Content-Type": "application/schema+json; charset=utf-8",
      "Cache-Control": "public, max-age=300",
      "Access-Control-Allow-Origin": "*",
    },
  });
}
