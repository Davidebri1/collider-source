// Empty until David sets a Google OAuth web client id and, for Apple, a
// Services ID. See tool/worker/DEPLOY.md. Do not put a secret here.
self.COLLIDER_GOOGLE_CLIENT_ID = "";
self.COLLIDER_APPLE_CLIENT_ID = "";

self.colliderGoogleSignIn = function () {
  return new Promise((resolve) => {
    const id = self.COLLIDER_GOOGLE_CLIENT_ID || "";
    if (!id) {
      resolve("");
      return;
    }
    const start = () => {
      google.accounts.id.initialize({
        client_id: id,
        callback: (resp) => resolve((resp && resp.credential) || ""),
      });
      google.accounts.id.prompt();
    };
    if (self.google && google.accounts && google.accounts.id) start();
    else {
      const s = document.createElement("script");
      s.src = "https://accounts.google.com/gsi/client";
      s.onload = start;
      s.onerror = () => resolve("");
      document.head.appendChild(s);
    }
  });
};

self.colliderCalendarToken = function () {
  return new Promise((resolve) => {
    const id = self.COLLIDER_GOOGLE_CLIENT_ID || "";
    if (!id) {
      resolve("");
      return;
    }
    const start = () => {
      const client = google.accounts.oauth2.initTokenClient({
        client_id: id,
        scope: "https://www.googleapis.com/auth/calendar.events",
        callback: (resp) => resolve((resp && resp.access_token) || ""),
      });
      client.requestAccessToken();
    };
    if (self.google && google.accounts && google.accounts.oauth2) start();
    else {
      const s = document.createElement("script");
      s.src = "https://accounts.google.com/gsi/client";
      s.onload = start;
      s.onerror = () => resolve("");
      document.head.appendChild(s);
    }
  });
};
