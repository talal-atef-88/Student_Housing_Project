-- Active: 1777833763088@@localhost@5432@student_housing
-- =============================================================
-- Student Housing Platform — PostgreSQL DDL (3NF)
-- =============================================================



CREATE EXTENSION IF NOT EXISTS citext;       -- case-insensitive emails
CREATE EXTENSION IF NOT EXISTS btree_gist;   -- needed for EXCLUDE on scalar + range

-- =============================================================
-- ENUM TYPES
-- =============================================================
CREATE TYPE user_role      AS ENUM ('student', 'owner', 'admin');
CREATE TYPE booking_status AS ENUM ('pending', 'confirmed', 'cancelled');
CREATE TYPE viewing_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE payment_method AS ENUM ('cash', 'online');
CREATE TYPE payment_status AS ENUM ('pending', 'paid', 'failed', 'refunded');

-- =============================================================
-- USERS
-- =============================================================
CREATE TABLE users (
    id            BIGSERIAL    PRIMARY KEY,
    full_name     TEXT         NOT NULL,
    email         CITEXT       NOT NULL UNIQUE,
    phone         TEXT         NOT NULL,
    password_hash TEXT         NOT NULL,
    role          user_role    NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE INDEX users_role_idx ON users (role);

-- =============================================================
-- PROPERTIES
-- =============================================================
CREATE TABLE properties (
    id            BIGSERIAL      PRIMARY KEY,
    owner_id      BIGINT         NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    title         TEXT           NOT NULL,
    description   TEXT,
    city          TEXT           NOT NULL,
    property_area          TEXT           NOT NULL,
    street        TEXT           NOT NULL,
    monthly_rent  NUMERIC(10, 2) NOT NULL CHECK (monthly_rent >= 0),
    num_rooms     INT            NOT NULL CHECK (num_rooms > 0),
    is_available  BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE INDEX properties_owner_idx     ON properties (owner_id);
CREATE INDEX properties_city_area_idx ON properties (city, property_area);

-- =============================================================
-- AMENITIES  (many-to-many with properties — kept out of plain text)
-- =============================================================
CREATE TABLE amenities (
    id   SERIAL PRIMARY KEY,
    name TEXT   NOT NULL UNIQUE
);

CREATE TABLE property_amenities (
    property_id BIGINT NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    amenity_id  INT    NOT NULL REFERENCES amenities(id)  ON DELETE RESTRICT,
    PRIMARY KEY (property_id, amenity_id)
);

-- =============================================================
-- ROOMS / BEDS
-- =============================================================
CREATE TABLE rooms (
    id          BIGSERIAL PRIMARY KEY,
    property_id BIGINT    NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    label       TEXT      NOT NULL,
    UNIQUE (property_id, label)
);

CREATE INDEX rooms_property_idx ON rooms (property_id);

CREATE TABLE beds (
    id      BIGSERIAL PRIMARY KEY,
    room_id BIGINT    NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
    label   TEXT      NOT NULL,
    UNIQUE (room_id, label)
);

CREATE INDEX beds_room_idx ON beds (room_id);

-- =============================================================
-- BOOKINGS  (target exactly one of: bed or room)
-- =============================================================
CREATE TABLE bookings (
    id          BIGSERIAL      PRIMARY KEY,
    student_id  BIGINT         NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    bed_id      BIGINT         REFERENCES beds(id)  ON DELETE RESTRICT,
    room_id     BIGINT         REFERENCES rooms(id) ON DELETE RESTRICT,
    start_date  DATE           NOT NULL,
    end_date    DATE           NOT NULL,
    status      booking_status NOT NULL DEFAULT 'pending',
    created_at  TIMESTAMPTZ    NOT NULL DEFAULT now(),

    CONSTRAINT booking_target_xor
        CHECK ((bed_id IS NOT NULL)::int + (room_id IS NOT NULL)::int = 1),
    CONSTRAINT booking_dates_valid
        CHECK (end_date > start_date),

    -- A bed cannot be double-booked across active bookings.
    CONSTRAINT booking_bed_no_overlap
        EXCLUDE USING gist (
            bed_id WITH =,
            daterange(start_date, end_date, '[)') WITH &&
        ) WHERE (status IN ('pending', 'confirmed') AND bed_id IS NOT NULL),

    -- A room cannot be double-booked across active bookings.
    CONSTRAINT booking_room_no_overlap
        EXCLUDE USING gist (
            room_id WITH =,
            daterange(start_date, end_date, '[)') WITH &&
        ) WHERE (status IN ('pending', 'confirmed') AND room_id IS NOT NULL),

    -- A student cannot hold two active bookings on overlapping dates.
    CONSTRAINT booking_student_no_overlap
        EXCLUDE USING gist (
            student_id WITH =,
            daterange(start_date, end_date, '[)') WITH &&
        ) WHERE (status IN ('pending', 'confirmed'))
);

CREATE INDEX bookings_student_idx ON bookings (student_id);
CREATE INDEX bookings_bed_idx     ON bookings (bed_id);
CREATE INDEX bookings_room_idx    ON bookings (room_id);
CREATE INDEX bookings_status_idx  ON bookings (status);

-- =============================================================
-- VIEWING REQUESTS
-- =============================================================
CREATE TABLE viewing_requests (
    id             BIGSERIAL      PRIMARY KEY,
    student_id     BIGINT         NOT NULL REFERENCES users(id)      ON DELETE RESTRICT,
    property_id    BIGINT         NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    preferred_date DATE           NOT NULL,
    status         viewing_status NOT NULL DEFAULT 'pending',
    created_at     TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE INDEX viewing_requests_property_idx ON viewing_requests (property_id);
CREATE INDEX viewing_requests_student_idx  ON viewing_requests (student_id);

-- =============================================================
-- REVIEWS  (one per student per property)
-- =============================================================
CREATE TABLE reviews (
    id          BIGSERIAL   PRIMARY KEY,
    student_id  BIGINT      NOT NULL REFERENCES users(id)      ON DELETE RESTRICT,
    property_id BIGINT      NOT NULL REFERENCES properties(id) ON DELETE CASCADE,
    rating      SMALLINT    NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (student_id, property_id)
);

CREATE INDEX reviews_property_idx ON reviews (property_id);

-- =============================================================
-- PAYMENTS
-- =============================================================
CREATE TABLE payments (
    id            BIGSERIAL      PRIMARY KEY,
    booking_id    BIGINT         NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    amount        NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    payment_date  DATE           NOT NULL,
    method        payment_method NOT NULL,
    status        payment_status NOT NULL DEFAULT 'pending'
);

CREATE INDEX payments_booking_idx ON payments (booking_id);

-- =============================================================
-- ROLE VALIDATION
-- The role column on users alone cannot guarantee that, e.g.,
-- properties.owner_id references a user whose role = 'owner'.
-- These triggers enforce that invariant at write time.
-- =============================================================
CREATE OR REPLACE FUNCTION assert_user_role(p_user_id BIGINT, p_role user_role)
RETURNS VOID AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id AND role = p_role) THEN
        RAISE EXCEPTION 'User % must have role %', p_user_id, p_role
            USING ERRCODE = 'check_violation';
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_assert_owner() RETURNS TRIGGER AS $$
BEGIN
    PERFORM assert_user_role(NEW.owner_id, 'owner');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION trg_assert_student() RETURNS TRIGGER AS $$
BEGIN
    PERFORM assert_user_role(NEW.student_id, 'student');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER properties_owner_role
    BEFORE INSERT OR UPDATE OF owner_id ON properties
    FOR EACH ROW EXECUTE FUNCTION trg_assert_owner();

CREATE TRIGGER bookings_student_role
    BEFORE INSERT OR UPDATE OF student_id ON bookings
    FOR EACH ROW EXECUTE FUNCTION trg_assert_student();

CREATE TRIGGER viewing_requests_student_role
    BEFORE INSERT OR UPDATE OF student_id ON viewing_requests
    FOR EACH ROW EXECUTE FUNCTION trg_assert_student();

CREATE TRIGGER reviews_student_role
    BEFORE INSERT OR UPDATE OF student_id ON reviews
    FOR EACH ROW EXECUTE FUNCTION trg_assert_student();
