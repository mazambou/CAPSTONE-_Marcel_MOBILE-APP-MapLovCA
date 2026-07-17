-- Allow chat documents while preserving the existing text/image/voice values.
alter type public.message_kind add value if not exists 'document';
