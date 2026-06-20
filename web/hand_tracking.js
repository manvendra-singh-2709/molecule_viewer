let handLandmarker = null;
let video = null;
let stream = null;
let running = false;
let lastCameraError = null;

async function ensureCameraVideo() {
  if (video && video.readyState >= 2 && stream) return video;

  video = document.getElementById("handTrackingVideo");

  if (!video) {
    video = document.createElement("video");
    video.id = "handTrackingVideo";
    video.autoplay = true;
    video.muted = true;
    video.playsInline = true;

    video.style.position = "fixed";
    video.style.left = "-9999px";
    video.style.top = "-9999px";
    video.style.width = "1px";
    video.style.height = "1px";
    video.style.opacity = "0";
    video.style.pointerEvents = "none";

    document.body.appendChild(video);
  }

  if (!stream) {
    try {
      stream = await navigator.mediaDevices.getUserMedia({
        video: {
          width: 1280,
          height: 720,
          facingMode: "user"
        },
        audio: false
      });

      video.srcObject = stream;
      lastCameraError = null;
    } catch (e) {
      lastCameraError = e.name || String(e);
      console.error("Camera permission/error:", e);
      return null;
    }
  }

  await video.play();

  for (let i = 0; i < 100; i++) {
    if (video.readyState >= 2) return video;
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  return null;
}

async function requestCameraAgain() {
  stream = null;

  if (video) {
    video.srcObject = null;
  }

  const ok = await initHandTracking();
  return ok;
}

function getCameraPermissionStatus() {
  return lastCameraError;
}

async function initHandTracking() {
  if (running && handLandmarker && video && stream) {
    return true;
  }

  console.log("Initializing MediaPipe Hands...");

  const vision = await import(
    "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest"
  );

  const filesetResolver = await vision.FilesetResolver.forVisionTasks(
    "https://cdn.jsdelivr.net/npm/@mediapipe/tasks-vision@latest/wasm"
  );

  if (!handLandmarker) {
    handLandmarker = await vision.HandLandmarker.createFromOptions(
      filesetResolver,
      {
        baseOptions: {
          modelAssetPath:
            "https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/latest/hand_landmarker.task",
          delegate: "GPU"
        },
        runningMode: "VIDEO",
        numHands: 2
      }
    );
  }

  video = await ensureCameraVideo();

  if (!video) {
    running = false;
    return false;
  }

  running = true;
  console.log("MediaPipe Hands ready");
  return true;
}

function distance2D(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

function isClosedFist(lm) {
  const wrist = lm[0];
  const tips = [lm[8], lm[12], lm[16], lm[20]];
  const mcps = [lm[5], lm[9], lm[13], lm[17]];

  let closedCount = 0;

  for (let i = 0; i < tips.length; i++) {
    if (distance2D(tips[i], wrist) < distance2D(mcps[i], wrist) * 1.25) {
      closedCount++;
    }
  }

  return closedCount >= 3;
}

function getPalmCenter(lm) {
  const wrist = lm[0];
  const indexMcp = lm[5];
  const middleMcp = lm[9];
  const pinkyMcp = lm[17];

  return {
    x: (wrist.x + indexMcp.x + middleMcp.x + pinkyMcp.x) / 4.0,
    y: (wrist.y + indexMcp.y + middleMcp.y + pinkyMcp.y) / 4.0
  };
}

function getHandGesture() {
  if (!handLandmarker || !video || video.readyState < 2 || !running) {
    return null;
  }

  const result = handLandmarker.detectForVideo(video, performance.now());

  if (!result.landmarks || result.landmarks.length === 0) {
    return null;
  }

  const mainHand = result.landmarks[0];

  if (isClosedFist(mainHand)) return null;

  let scaleDistance;

  if (result.landmarks.length >= 2) {
    scaleDistance = distance2D(result.landmarks[0][8], result.landmarks[1][8]);
  } else {
    scaleDistance = distance2D(mainHand[4], mainHand[8]);
  }

  const palmCenter = getPalmCenter(mainHand);

  return {
    pinchDistance: scaleDistance,
    rotationX: palmCenter.y,
    rotationY: palmCenter.x,
    rotationZ: 0.0
  };
}

async function showCameraVideoInContainer(containerId) {
  const container = document.getElementById(containerId);
  if (!container) return false;

  const ok = await initHandTracking();
  if (!ok) return false;

  const video = document.getElementById("handTrackingVideo");
  if (!video) return false;

  video.style.position = "static";
  video.style.left = "auto";
  video.style.top = "auto";
  video.style.width = "100%";
  video.style.height = "100%";
  video.style.opacity = "1";
  video.style.objectFit = "cover";
  video.style.transform = "scaleX(-1)";
  video.style.pointerEvents = "none";

  if (video.parentElement !== container) {
    container.innerHTML = "";
    container.appendChild(video);
  }

  return true;
}

function hideCameraVideo() {
  const video = document.getElementById("handTrackingVideo");

  if (!video) {
    return false;
  }

  video.style.position = "fixed";
  video.style.left = "-9999px";
  video.style.top = "-9999px";
  video.style.width = "1px";
  video.style.height = "1px";
  video.style.opacity = "0";
  video.style.pointerEvents = "none";

  return true;
}

function showCameraVideo() {
  const video = document.getElementById("handTrackingVideo");

  if (!video) {
    return false;
  }

  video.style.position = "fixed";
  video.style.left = "0";
  video.style.top = "0";
  video.style.width = "100vw";
  video.style.height = "100vh";
  video.style.opacity = "1";
  video.style.objectFit = "cover";
  video.style.transform = "scaleX(-1)";
  video.style.pointerEvents = "none";

  return true;
}