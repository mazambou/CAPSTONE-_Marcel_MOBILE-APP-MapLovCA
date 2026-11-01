import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization, x-client-info, apikey, content-type',
  'access-control-allow-methods': 'POST, OPTIONS',
};
const json = (status: number, body: Record<string, unknown>) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json', ...corsHeaders },
  });

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== 'POST') return json(405, { error: 'method_not_allowed' });
  const token = request.headers.get('authorization')?.replace(/^Bearer\s+/i, '');
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!token || !url || !anonKey || !serviceKey) {
    return json(401, { error: 'unauthorized' });
  }
  const caller = createClient(url, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: identity, error: identityError } = await caller.auth.getUser(token);
  if (identityError || !identity.user) return json(401, { error: 'unauthorized' });
  let payload: Record<string, unknown>;
  try {
    payload = await request.json();
    if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
      return json(400, { error: 'invalid_body' });
    }
  } catch {
    return json(400, { error: 'invalid_body' });
  }
  let reportId = String(payload.reportId ?? '');
  if (!reportId) {
    const targetType = String(payload.targetType ?? '');
    const targetId = String(payload.targetId ?? '');
    const reason = String(payload.reason ?? '');
    const comment = payload.comment == null ? null : String(payload.comment);
    const conversationId = payload.conversationId == null
      ? null : String(payload.conversationId);
    if (!['user', 'message'].includes(targetType) ||
      !/^[0-9a-f-]{36}$/i.test(targetId) ||
      (conversationId != null && !/^[0-9a-f-]{36}$/i.test(conversationId)) ||
      reason.length < 2 || reason.length > 120 ||
      (comment?.length ?? 0) > 4000) {
      return json(400, { error: 'invalid_report' });
    }
    const { data: createdId, error: createError } = await caller.rpc(
      'submit_conversation_report', {
        target_type_value: targetType,
        target_id_value: targetId,
        reason_value: reason,
        comment_value: comment,
        conversation_id_value: conversationId,
      }
    );
    if (createError || typeof createdId !== 'string') {
      return json(409, { error: 'report_unavailable' });
    }
    reportId = createdId;
  }
  if (!/^[0-9a-f-]{36}$/i.test(reportId)) return json(400, { error: 'invalid_report' });
  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: report, error: reportError } = await admin
    .from('reports').select('id,reporter_id').eq('id', reportId).maybeSingle();
  if (reportError || !report || report.reporter_id !== identity.user.id) {
    return json(403, { error: 'report_unavailable' });
  }
  const { data: evidence, error: evidenceError } = await admin
    .from('report_conversation_evidence')
    .select('messages,attachments,media_finalized_at')
    .eq('report_id', reportId).maybeSingle();
  if (evidenceError || !evidence) return json(409, { error: 'evidence_unavailable' });
  if (evidence.media_finalized_at) return json(200, { saved: true });

  const attachments: { message_id: string; path: string; original_path: string }[] = [];
  for (const message of evidence.messages ?? []) {
    const originalPath = message.media_path;
    if (typeof originalPath !== 'string' || originalPath.length === 0) continue;
    const messageId = String(message.id);
    const extension = originalPath.split('.').pop()?.replace(/[^a-z0-9]/gi, '') || 'bin';
    const path = `${reportId}/${messageId}.${extension}`;
    const { data: file, error: downloadError } = await admin.storage
      .from('chat-media').download(originalPath);
    if (downloadError || !file) {
      return json(503, { error: 'attachment_copy_failed', messageId });
    }
    const { error: uploadError } = await admin.storage
      .from('moderation-evidence').upload(path, file, {
        upsert: true,
        contentType: file.type || 'application/octet-stream',
      });
    if (uploadError) return json(503, { error: 'attachment_copy_failed', messageId });
    attachments.push({ message_id: messageId, path, original_path: originalPath });
  }
  const { error: updateError } = await admin
    .from('report_conversation_evidence')
    .update({ attachments, media_finalized_at: new Date().toISOString() })
    .eq('report_id', reportId);
  if (updateError) return json(503, { error: 'evidence_finalization_failed' });
  return json(200, { saved: true });
});
