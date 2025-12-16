// ==================================================
// QR CLOUD – FRONTEND CONTROLLER
// ==================================================


// ==================================================
// CREATE QR CODE
// ==================================================
async function generateQR(event) {
  if (event) event.preventDefault();

  const message = document.getElementById("qrMessage")?.value.trim();
  const expiry  = document.getElementById("qrExpiry")?.value || null;
  const color   = document.getElementById("qrColor")?.value || "#000000";

  if (!message) {
    alert("Please enter a message or URL.");
    return;
  }

  try {
    const result = await apiCreateQR({
      originalUrl: message,
      theme: color,
      expiryTime: expiry,
      userId: "anonymous"
    });

    // Validate minimal response
    if (!result || !result.qrId) {
      throw new Error("Invalid QR API response");
    }

    // Show result box
    document.getElementById("qrResult")?.classList.remove("hidden");

    // Hide image preview (PDF-first system)
    const img = document.getElementById("qrImage");
    if (img) img.style.display = "none";

    // PDF Download
    const pdfBtn = document.getElementById("downloadPdf");
    if (pdfBtn && result.qrPdfUrl) {
      pdfBtn.href = result.qrPdfUrl;
      pdfBtn.target = "_blank";
      pdfBtn.style.pointerEvents = "auto";
      pdfBtn.style.opacity = "1";
    }

    // Disable PNG safely (if exists)
    const pngBtn = document.getElementById("downloadPng");
    if (pngBtn) {
      pngBtn.removeAttribute("href");
      pngBtn.style.pointerEvents = "none";
      pngBtn.style.opacity = "0.5";
    }

    // Enable Analytics link
    const analyticsBtn = document.getElementById("viewAnalytics");
    if (analyticsBtn) {
      analyticsBtn.href = `analytics.html?id=${result.qrId}`;
      analyticsBtn.classList.remove("hidden");
    }

  } catch (err) {
    console.error("QR Generation Error:", err);
    alert("Failed to generate QR. Please try again.");
  }
}


// ==================================================
// LOAD ALL QR CODES (DASHBOARD)
// ==================================================
async function loadQRCodes() {
  const tbody = document.getElementById("qrTableBody");
  if (!tbody) return;

  tbody.innerHTML = "";

  try {
    const results = await apiGetAllQR();
    if (!Array.isArray(results)) return;

    results.forEach(qr => {
      const row = document.createElement("tr");

      row.innerHTML = `
        <td>${qr.originalUrl || "-"}</td>
        <td>${qr.createdAt || "-"}</td>
        <td>${qr.expiryTime || "-"}</td>
        <td>${qr.expired ? "Expired" : "Active"}</td>
        <td>
          ${qr.qrPdfUrl ? `<a href="${qr.qrPdfUrl}" target="_blank">PDF</a>` : ""}
          <a href="analytics.html?id=${qr.qrId}">Analytics</a>
          <button type="button" onclick="deleteQR('${qr.qrId}')">Delete</button>
        </td>
      `;

      tbody.appendChild(row);
    });

  } catch (err) {
    console.error("Failed to load QR list:", err);
  }
}


// ==================================================
// DELETE QR
// ==================================================
async function deleteQR(qrId) {
  if (!qrId) return;
  if (!confirm("Are you sure you want to delete this QR code?")) return;

  try {
    await apiDeleteQR(qrId);
    loadQRCodes();
  } catch (err) {
    console.error("Delete failed:", err);
    alert("Unable to delete QR.");
  }
}


// ==================================================
// ANALYTICS PAGE
// ==================================================
async function loadAnalytics() {
  const params = new URLSearchParams(window.location.search);
  const qrId = params.get("id");

  if (!qrId) {
    console.warn("No QR ID provided");
    return;
  }

  try {
    const data = await apiGetAnalytics(qrId);

    if (!data || !Array.isArray(data.dates) || data.dates.length === 0) {
      document.getElementById("noData")?.classList.remove("hidden");
      return;
    }

    const ctx = document.getElementById("scanChart");
    if (!ctx) return;

    new Chart(ctx, {
      type: "line",
      data: {
        labels: data.dates,
        datasets: [{
          label: "QR Scans",
          data: data.counts || [],
          borderWidth: 2,
          tension: 0.3
        }]
      },
      options: {
        responsive: true,
        scales: {
          y: {
            beginAtZero: true,
            ticks: { precision: 0 }
          }
        }
      }
    });

  } catch (err) {
    console.error("Analytics load failed:", err);
    document.getElementById("noData")?.classList.remove("hidden");
  }
}
