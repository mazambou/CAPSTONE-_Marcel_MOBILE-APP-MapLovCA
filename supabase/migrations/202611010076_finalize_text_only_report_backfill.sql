-- The legacy open report has no surviving attachments to copy. Mark its
-- available metadata snapshot complete without claiming erased text exists.
update public.report_conversation_evidence e
set media_finalized_at=now()
where media_finalized_at is null
  and not exists (
    select 1 from jsonb_array_elements(e.messages) m
    where nullif(m->>'media_path','') is not null
  );
