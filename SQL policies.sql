-- User creation
CREATE USER ai_agent_user WITH PASSWORD 'secure_random_password';
-- Selection permission
GRANT SELECT ON courses, events, categories,
platforms, subjects, exams, video_on_demands, videos, testimonials,
public_featured_events, category_courses TO ai_agent_user;
-- View creation
CREATE VIEW ai_safe_users AS SELECT id,
first_name, last_name, email, company_id, origin_region, active_regions, created_at,
updated_at, archived, active FROM users;
CREATE VIEW ai_safe_courses AS SELECT id, slug, title, abbreviation, platform_id, price, origin_region,
active_regions, created_at, updated_at, option_for, developed_by_nterone, search_terms
FROM courses
CREATE VIEW ai_safe_events AS SELECT id, start_date, end_date, format, price, course_id,
guaranteed, active, start_time, end_time, city, state, status, public, language, instructor_id, time_zone,
archived, approved, max_student_count, origin_region, active_regions FROM events;
CREATE VIEW ai_safe_instructors AS SELECT id, first_name, last_name, biography, platform_id, status, archived,
origin_region, active_regions
FROM instructors
GRANT SELECT ON ai_safe_users, ai_safe_events, ai_safe_instructors, ai_safe_courses TO ai_agent_user;


-- Connection Policies
ALTER USER ai_agent_user CONNECTION LIMIT 21;
ALTER USER ai_agent_user SET statement_timeout = '30s';
ALTER USER ai_agent_user SET lock_timeout = '10s';


-- Policies creation
CREATE POLICY ai_agent_user_policy
ON users FOR SELECT TO ai_agent_user USING (active = true AND archived = false)

CREATE POLICY ai_agent_course_policy
ON courses FOR SELECT TO ai_agent_user USING (hidden_from_public = false AND archived = false);

CREATE POLICY ai_agent_event_policy
ON events FOR SELECT TO ai_agent_user USING (active = true AND public = true);

-- Enforce policies
ALTER TABLE courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;