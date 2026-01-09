Data Engineering Internship Project: Humanitarian Aid Management System

Internship Context  
Position: Data Engineering Intern  
Organization: Yasmeen AI  
Affiliation: Syrian Community for Data Science and AI  
Parent Organization: Alrifai Consulting Group  

Project Overview  
During my internship with Yasmeen AI, I designed and implemented a PostgreSQL-based schema to support a Humanitarian Aid Distribution Management System. The project focused on building a relational database that enables NGOs to manage beneficiaries, track distribution rounds, monitor attendance, handle complaints, and enforce financial controls. This work provided a foundation for scalable, transparent, and compliant aid management operations.

Key Responsibilities & Achievements  

Database Architecture & Modeling  
- Designed normalized tables for Projects, Beneficiaries, DistributionRounds, Attendance, Complaints, Payments, and Budgets  
- Established referential integrity with cascading deletes to maintain consistency  
- Defined ENUM types for statuses (complaints, attendance, approvals)  
- Added indexes on foreign keys and frequently queried columns to improve query performance  

Financial Controls  
- Implemented a trigger function (prevent_overspending) to block payments that exceed allocated budgets  
- Enforced constraints for valid payment amounts and positive budget allocations  

Security & Compliance  
- Enabled Row-Level Security (RLS) for region-based access to distribution data  
- Built an audit log capturing updates to beneficiary records, including user IDs and client IPs  
- Created a helper function (get_app_region) to support multi-region deployments  

Analytics & Reporting  
- Developed a materialized view (Daily_Distribution_Summary) for quick reporting on daily distribution activity  
- Created aggregate tables for financial spending and attendance tracking  
- Structured schema for efficient joins across large datasets  

Technical Skills Applied  
Database Design: Normalization, indexing, constraints  
PostgreSQL: PL/pgSQL triggers, materialized views, RLS policies, ENUM types, extensions (pgcrypto)  
Data Governance: Audit logging, validation, access control  
Performance Tuning: Query optimization and schema structuring  

Business Impact  
- Prevented overspending through automated budget controls  
- Improved reporting efficiency with pre-aggregated views and materialized summaries  
- Enhanced compliance via audit trails and secure access policies  
- Supported scalability for multi-region humanitarian deployments  

Internship Learning Outcomes  
- Gained hands-on experience in production-grade database design  
- Learned to balance performance, compliance, and security in sensitive data environments  
- Applied data engineering principles to real-world humanitarian challenges  
- Contributed to Yasmeen AI’s initiative under the Syrian Community for Data Science and AI  

