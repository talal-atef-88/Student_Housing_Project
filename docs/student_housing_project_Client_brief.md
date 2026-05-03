# 🧾 Client Brief: Student Housing Platform

## 🎯 Project Goal
Build a **database system** for a platform where:
- Students can search for available housing
- Property owners can list their properties
- Students can book or request to view a place

---

## 🧩 Core Requirements

### 1. Users
We have 3 types of users:
- Students (looking for housing)
- Property Owners (listing properties)
- Admins (manage the platform)

Each user should have:
- Name
- Email
- Phone number
- Password
- Role (Student / Owner / Admin)

---

### 2. Properties
Each property:
- Owned by a specific owner
- Has:
  - Title
  - Description
  - Address (city, area, street)
  - Price (monthly rent)
  - Number of rooms
  - Amenities (WiFi, kitchen, AC, etc.)
  - Availability status (available / not available)

---

### 3. Rooms / Beds
Some properties are shared:
- A property can have multiple rooms
- A room can have multiple beds
- Each bed may be booked separately

---

### 4. Bookings
Students can:
- Book a **bed or a full room**

Each booking should include:
- Student
- Property / Room / Bed
- Start date
- End date
- Status (pending / confirmed / cancelled)

---

### 5. Viewing Requests
Before booking, students might:
- Request to **visit** a property

Each request:
- Student
- Property
- Preferred date
- Status (pending / approved / rejected)

---

### 6. Reviews
After staying, students can:
- Leave a review on a property

Each review:
- Student
- Property
- Rating (1–5)
- Comment

---

### 7. Payments (simple for now)
- Each booking may have a payment
- Track:
  - Amount
  - Payment date
  - Method (cash / online)
  - Status

---

## ⚠️ Real-World Constraints
- A student **cannot double-book overlapping dates**
- A bed **cannot be booked by two students at the same time**
- Owners can have **multiple properties**
- Amenities should NOT be stored as plain text

---

## 📌 Your Tasks
1. Identify entities and attributes  
2. Design ERD (conceptually)  
3. Convert to relational schema  
4. Apply normalization (up to 3NF at least)  
5. Define primary and foreign keys  
6. Handle many-to-many relationships  
7. Consider basic scalability  

---

## 💬 Next Step
Start by identifying:
- Entities
- Assumptions or questions to clarify with the client
