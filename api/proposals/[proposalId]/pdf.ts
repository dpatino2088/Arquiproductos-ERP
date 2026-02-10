/**
 * Stub: Proposal PDF generation.
 * Returns 501 Not Implemented. Replace with real PDF generation (e.g. Edge Function or server-side render).
 */

export const config = { runtime: 'edge' };

export function GET(request: Request): Response {
  const url = new URL(request.url);
  const proposalId = url.pathname.split('/').filter(Boolean).pop();
  if (!proposalId) {
    return new Response(JSON.stringify({ message: 'Missing proposal ID' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }
  return new Response(
    JSON.stringify({ message: 'TODO', proposalId }),
    { status: 501, headers: { 'Content-Type': 'application/json' } }
  );
}
