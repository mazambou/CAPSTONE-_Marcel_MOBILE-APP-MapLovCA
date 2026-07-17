-- Enum additions are committed separately before they are referenced.
alter type public.report_target_type add value if not exists 'message';
