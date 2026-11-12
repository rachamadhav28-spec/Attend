# AI timetable reader (already applied to the Attendtrack project)
1. Table `ai_usage` + function `bump_ai_usage` enforce 10 reads per user per day.
2. Edge function `read-timetable` (JWT required) calls Groq. The key lives only in Supabase.
3. Add the secret: Supabase dashboard > Edge Functions > Secrets > `GROQ_API_KEY`.
