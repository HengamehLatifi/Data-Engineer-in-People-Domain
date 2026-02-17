-- Create raw_candidates Table
CREATE TABLE raw_candidates (
    candidate_id INT PRIMARY KEY,
    full_name VARCHAR(100),
    source VARCHAR(50),
    profile_created_date DATE
);

-- Create raw_applications Table
CREATE TABLE raw_applications (
    app_id INT PRIMARY KEY,
    candidate_id INT REFERENCES raw_candidates(candidate_id),
    role_level VARCHAR(20) CHECK (role_level IN ('Junior', 'Senior', 'Executive')),
    applied_date DATE NOT NULL,
    decision_date DATE NULL,
    expected_salary NUMERIC(12, 2)
);

-- Create raw_interviews Table
CREATE TABLE raw_interviews (
    interview_id INT PRIMARY KEY,
    app_id INT REFERENCES raw_applications(app_id),
    interview_date DATE,
    outcome VARCHAR(20) CHECK (outcome IN ('Passed', 'Rejected', 'No Show'))
);