-- Date parsing can depend on PostgreSQL session settings such as DateStyle.
-- Mark the helper STABLE so the planner does not treat it as globally immutable.

begin;

alter function private.safe_date(text) stable;

commit;
