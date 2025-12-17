![Architecture Diagram](Architecture%20Diagram.png)

🎥 **Watch the project video walkthrough:**  
https://youtube.com/watch?v=YEmgCauRglo&si=vb6EaTkXh76_kFEs


# QR Cloud Platform 🚀

A fully serverless **QR code generation and management platform** built on AWS — designed to be fast, scalable, and production-ready.

This project allows users to **generate QR codes, download them as PDFs, and manage QR metadata**, all through a clean web interface backed by modern cloud infrastructure. The entire system is built with real-world architecture patterns used in production environments.

---

## ✨ Why This Project Exists

Most QR tools are simple generators with no real backend thinking.

**QR Cloud Platform** was built to go beyond that:
- Serverless, scalable, and cost-efficient
- Secure user authentication
- Clean separation of frontend, APIs, and infrastructure
- Designed like a real SaaS backend, not a demo app

This project reflects how modern cloud systems are actually designed and deployed.

---

## 🧩 Key Features

- 🔹 Generate QR codes from any text or URL  
- 🔹 Download QR codes as **PDF files** stored in S3  
- 🔹 Secure API access using Amazon Cognito  
- 🔹 Metadata storage using DynamoDB  
- 🔹 Fully serverless architecture (no servers to manage)  
- 🔹 CloudFront for fast global delivery  
- 🔹 Infrastructure managed with Terraform  

---

## 🏗️ Architecture Overview

**High-level flow:**


Frontend (UI)
↓
CloudFront
↓
API Gateway
↓
AWS Lambda
↓
S3 (QR PDFs) & DynamoDB (metadata)



**Services Used:**
- **AWS Lambda** – QR generation & backend logic  
- **API Gateway** – Public API endpoints  
- **S3** – QR PDFs storage  
- **DynamoDB** – QR metadata storage  
- **CloudFront** – UI hosting & fast delivery  
- **Cognito** – User authentication  
- **Terraform** – Infrastructure as Code  

---

This structure keeps infrastructure clean, modular, and easy to maintain.

---

## ⚙️ Tech Stack

- **Frontend:** HTML, CSS, JavaScript  
- **Backend:** AWS Lambda (Python)  
- **Infrastructure:** Terraform  
- **Storage:** Amazon S3, DynamoDB  
- **Auth:** Amazon Cognito  
- **Delivery:** CloudFront  

---

## 🚀 What This Project Demonstrates

- Real-world serverless architecture design  
- Clean separation of concerns  
- Secure authentication flows  
- Cloud-native thinking  
- Production-ready AWS patterns  

This is not a tutorial project — it’s a **portfolio-grade cloud system**.

---

## 📌 Status

✅ Core system complete  
🔒 Secure  
📦 Fully serverless  
☁️ Cloud-native  

Future enhancements (optional):
- Advanced analytics
- Scan tracking dashboards
- Rate limiting & monitoring

---

## 🙌 Final Note

This project represents how I approach cloud engineering:  
**clean architecture, scalability first, and real-world practices.**

If you’re reviewing this as a recruiter or engineer — feel free to explore the infrastructure and Lambda logic. Everything here is built intentionally.

---
