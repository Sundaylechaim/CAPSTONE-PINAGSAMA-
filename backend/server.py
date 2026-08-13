from flask import Flask, Response
from flask_cors import CORS
import cv2
import mediapipe as mp

app = Flask(__name__)
CORS(app)

# Initialize MediaPipe Hands with optimized confidence for motion
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=2,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)
mp_draw = mp.solutions.drawing_utils

camera = cv2.VideoCapture(0)

# Keep track of previous landmarks to smooth out jitter/flickering
prev_landmarks = None

def generate_frames():
    global prev_landmarks
    while True:
        success, frame = camera.read()
        if not success:
            break
        
        # Mirror view for natural interaction
        frame = cv2.flip(frame, 1)
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(rgb_frame)
        
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                # Basic blending/smoothing to reduce abrupt skeleton flickering
                if prev_landmarks is not None:
                    for i, lm in enumerate(hand_landmarks.landmark):
                        prev_lm = prev_landmarks[i]
                        lm.x = prev_lm.x * 0.3 + lm.x * 0.7
                        lm.y = prev_lm.y * 0.3 + lm.y * 0.7
                        lm.z = prev_lm.z * 0.3 + lm.z * 0.7
                
                prev_landmarks = hand_landmarks.landmark

                mp_draw.draw_landmarks(
                    frame, 
                    hand_landmarks, 
                    mp_hands.HAND_CONNECTIONS,
                    mp_draw.DrawingSpec(color=(0, 255, 0), thickness=2, circle_radius=2),
                    mp_draw.DrawingSpec(color=(255, 0, 0), thickness=2, circle_radius=2)
                )
        else:
            # Gradually clear if hand leaves frame completely
            prev_landmarks = None

        ret, buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
        frame_bytes = buffer.tobytes()
        
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')

@app.route('/video_feed')
def video_feed():
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=True)