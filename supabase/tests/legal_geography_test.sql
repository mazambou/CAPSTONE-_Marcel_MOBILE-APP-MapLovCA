begin;

do $$
declare
  required_document_count integer;
  geography_column_count integer;
begin
  select count(*) into required_document_count
  from public.legal_documents
  where is_required and version = '2026-07-16';

  if required_document_count <> 5 then
    raise exception 'Expected 5 required legal documents, found %',
      required_document_count;
  end if;

  select count(*) into geography_column_count
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'profiles'
    and column_name in (
      'residence_country_name',
      'residence_city',
      'origin_country_name',
      'origin_city'
    );

  if geography_column_count <> 4 then
    raise exception 'The four profile geography columns are not available';
  end if;

  if not exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = 'user_legal_acceptances'
      and c.relrowsecurity
  ) then
    raise exception 'RLS must be enabled on user_legal_acceptances';
  end if;
end;
$$;

rollback;
