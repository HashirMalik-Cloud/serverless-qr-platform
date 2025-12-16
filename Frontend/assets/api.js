// ===============================
//  API CONFIG
// ===============================
const API_BASE = "https://8kkz3dljti.execute-api.us-east-1.amazonaws.com/prod";


// ===============================
//  GENERIC API CALLER
// ===============================
async function callAPI(path, method = "GET", body = null) {
  const token = localStorage.getItem("id_token");

  const options = {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token && { "Authorization": `Bearer ${token}` })
    }
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  let res;

  try {
    res = await fetch(`${API_BASE}${path}`, options);
  } catch (networkErr) {
    console.error("NETWORK ERROR:", networkErr);
    throw new Error("Network error. Check your internet or API Gateway.");
  }

  if (!res.ok) {
    const text = await res.text();
    console.error("API ERROR RESPONSE:", text);
    throw new Error(`API Error ${res.status}: ${text}`);
  }

  try {
    return await res.json();
  } catch {
    return {};
  }
}


// ===============================
//        QR CREATION
//   POST /qr
// ===============================
async function apiCreateQR(payload) {
  return await callAPI("/qr", "POST", payload);
}


// ===============================
//       LIST ALL QR CODES
//   GET /scan?list=true
// ===============================
async function apiGetAllQR() {
  return await callAPI("/scan?list=true", "GET");
}


// ===============================
//          ANALYTICS
//     GET /scan?id=xxxx
// ===============================
async function apiGetAnalytics(id) {
  return await callAPI(`/scan?id=${id}`, "GET");
}


// ===============================
//        DELETE QR CODE
//     DELETE /qr?id=xxxx
// ===============================
async function apiDeleteQR(id) {
  return await callAPI(`/qr?id=${id}`, "DELETE");
}
