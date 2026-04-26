# ============================================================
# collect_data.py
# Recolección de landmarks de mano para LSC MVP (A y B)
# Controles: ESPACIO = guardar muestra | Q = salir
# ============================================================

import cv2
import mediapipe as mp
import csv
import os
import sys

# ─────────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────────
OUTPUT_FILE   = "dataset.csv"
SAMPLES_GOAL  = 30          # muestras por letra
LABELS        = ["A", "B"]  # letras a recolectar

# ─────────────────────────────────────────────
# DETECCIÓN DE CÁMARAS DISPONIBLES
# ─────────────────────────────────────────────
def find_available_cameras(max_test=6):
    """Prueba índices 0-5 y devuelve los que abren correctamente."""
    available = []
    print("\n🔍 Buscando cámaras disponibles...")
    
    camera_names = []
    try:
        from pygrabber.dshow_graph import FilterGraph
        graph = FilterGraph()
        camera_names = graph.get_input_devices()
    except ImportError:
        pass

    for i in range(max_test):
        cap = cv2.VideoCapture(i)  # Usar backend por defecto en lugar de CAP_DSHOW
        if cap.isOpened():
            ret, frame = cap.read()
            if ret and frame is not None:
                w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
                h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
                name = camera_names[i] if i < len(camera_names) else f"Cámara {i}"
                available.append({"index": i, "name": name, "res": f"{w}x{h}"})
                print(f"   ✅ [{i}] {name} — {w}x{h}")
        cap.release()
    return available


def select_camera(cameras):
    """Pide al usuario que elija una cámara por índice."""
    if not cameras:
        print("❌ No se encontraron cámaras. Verifica conexiones.")
        sys.exit(1)

    if len(cameras) == 1:
        print(f"\n📷 Usando única cámara disponible: [{cameras[0]['index']}] {cameras[0]['name']}")
        return cameras[0]["index"]

    print("\n📷 Cámaras disponibles:")
    for cam in cameras:
        print(f"   [{cam['index']}] {cam['name']} — {cam['res']}")

    while True:
        try:
            choice = int(input("\n👉 Ingresa el número de cámara a usar: "))
            if any(c["index"] == choice for c in cameras):
                return choice
            print("   ⚠️  Opción no válida. Intenta de nuevo.")
        except ValueError:
            print("   ⚠️  Ingresa solo un número.")


# ─────────────────────────────────────────────
# INICIALIZAR CSV (agrega header si es nuevo)
# ─────────────────────────────────────────────
def init_csv(filepath):
    if not os.path.exists(filepath):
        with open(filepath, "w", newline="") as f:
            writer = csv.writer(f)
            header = [f"{axis}{i}" for i in range(21) for axis in ["x","y","z"]]
            header.append("label")
            writer.writerow(header)
        print(f"📄 Archivo creado: {filepath}")
    else:
        print(f"📄 Agregando a archivo existente: {filepath}")


# ─────────────────────────────────────────────
# CONTAR MUESTRAS YA RECOLECTADAS
# ─────────────────────────────────────────────
def count_existing_samples(filepath, label):
    if not os.path.exists(filepath):
        return 0
    count = 0
    with open(filepath, "r") as f:
        reader = csv.reader(f)
        next(reader, None)  # saltar header
        for row in reader:
            if row and row[-1] == label:
                count += 1
    return count


# ─────────────────────────────────────────────
# RECOLECTAR MUESTRAS PARA UNA LETRA
# ─────────────────────────────────────────────
def collect_label(cap, label, goal, output_file):
    mp_hands   = mp.solutions.hands
    mp_draw    = mp.solutions.drawing_utils
    hands      = mp_hands.Hands(
        static_image_mode=False,
        max_num_hands=1,
        min_detection_confidence=0.7,
        min_tracking_confidence=0.6,
    )

    existing = count_existing_samples(output_file, label)
    needed   = max(0, goal - existing)

    if needed == 0:
        print(f"\n✅ Ya tienes {existing} muestras de '{label}' — saltando.\n")
        hands.close()
        return

    print(f"\n{'='*50}")
    print(f"  Letra: {label}  |  Ya tienes: {existing}  |  Necesitas: {needed} más")
    print(f"  ESPACIO = guardar muestra  |  Q = salir")
    print(f"{'='*50}")
    input(f"\n  Prepara tu mano en posición '{label}' y presiona ENTER para comenzar...")
    print("  👉 ¡IMPORTANTE: Haz clic en la ventana de la cámara antes de presionar espacio o Q!")

    count       = 0
    last_saved  = 0   # feedback visual de guardado (contador de frames)
    window_name = f"LSC Collector — Letra {label}"
    cv2.namedWindow(window_name)
    cv2.setWindowProperty(window_name, cv2.WND_PROP_TOPMOST, 1)

    with open(output_file, "a", newline="") as f:
        writer = csv.writer(f)

        while count < needed:
            ret, frame = cap.read()
            if not ret:
                print("⚠️  Error leyendo frame.")
                break

            frame   = cv2.flip(frame, 1)                          # espejo más natural
            rgb     = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            result  = hands.process(rgb)
            overlay = frame.copy()

            hand_detected = False
            key = cv2.waitKey(1) & 0xFF

            if key == ord('q'):
                print("\n⚠️  Recolección interrumpida por el usuario.")
                break

            if result.multi_hand_landmarks:
                hand_detected = True
                lm_list = result.multi_hand_landmarks[0]
                mp_draw.draw_landmarks(overlay, lm_list, mp_hands.HAND_CONNECTIONS,
                    mp_draw.DrawingSpec(color=(0,255,0), thickness=2, circle_radius=3),
                    mp_draw.DrawingSpec(color=(255,255,255), thickness=2))

                if key == ord(' '):
                    row = []
                    for lm in lm_list.landmark:
                        row.extend([round(lm.x, 6), round(lm.y, 6), round(lm.z, 6)])
                    row.append(label)
                    writer.writerow(row)
                    f.flush()
                    count      += 1
                    last_saved  = 15  # mostrar feedback por 15 frames (~0.5 seg)

            # ── UI ──────────────────────────────────────────
            total_saved = existing + count
            progress    = int((count / needed) * 20)
            bar         = "█" * progress + "░" * (20 - progress)

            # Fondo semitransparente para el panel
            panel = overlay.copy()
            cv2.rectangle(panel, (0, 0), (420, 130), (20, 20, 20), -1)
            cv2.addWeighted(panel, 0.6, overlay, 0.4, 0, overlay)

            cv2.putText(overlay, f"Letra: {label}",
                        (10, 28), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (255,255,255), 2)
            cv2.putText(overlay, f"Sesion: {count}/{needed}   Total: {total_saved}/{goal}",
                        (10, 56), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (200,200,200), 1)
            cv2.putText(overlay, f"[{bar}]",
                        (10, 80), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (0,220,0), 1)

            status_color = (0,255,0) if hand_detected else (0,100,255)
            status_text  = "Mano detectada ✓" if hand_detected else "Sin mano detectada"
            cv2.putText(overlay, status_text,
                        (10, 108), cv2.FONT_HERSHEY_SIMPLEX, 0.55, status_color, 1)

            # Flash verde cuando se guarda
            if last_saved > 0:
                cv2.rectangle(overlay, (0,0), (overlay.shape[1], overlay.shape[0]),
                              (0,255,0), 6)
                cv2.putText(overlay, "GUARDADO!",
                            (overlay.shape[1]//2 - 70, overlay.shape[0]//2),
                            cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0,255,0), 3)
                last_saved -= 1

            cv2.imshow(window_name, overlay)

    hands.close()
    cv2.destroyAllWindows()

    final_count = count_existing_samples(output_file, label)
    print(f"\n✅ '{label}' completado — {final_count}/{goal} muestras en total.")


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
def main():
    print("╔══════════════════════════════════════╗")
    print("║   LSC Data Collector — MVP (A / E)   ║")
    print("╚══════════════════════════════════════╝")

    # 1. Selección de cámara
    cameras     = find_available_cameras()
    cam_index   = select_camera(cameras)

    cap = cv2.VideoCapture(cam_index)
    # cap.set(cv2.CAP_PROP_FRAME_WIDTH,  1280)  # Evita congelamientos con cámaras virtuales
    # cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)

    if not cap.isOpened():
        print(f"❌ No se pudo abrir la cámara {cam_index}.")
        sys.exit(1)

    print(f"\n✅ Cámara {cam_index} abierta correctamente.")

    # 2. Inicializar CSV
    init_csv(OUTPUT_FILE)

    # 3. Recolectar cada letra
    for label in LABELS:
        collect_label(cap, label, SAMPLES_GOAL, OUTPUT_FILE)

    cap.release()

    # 4. Resumen final
    print("\n" + "="*50)
    print("  RESUMEN FINAL")
    print("="*50)
    for label in LABELS:
        n = count_existing_samples(OUTPUT_FILE, label)
        status = "✅" if n >= SAMPLES_GOAL else f"⚠️  ({n}/{SAMPLES_GOAL})"
        print(f"  {label}: {n} muestras  {status}")
    print(f"\n  Dataset guardado en: {OUTPUT_FILE}")
    print("  Siguiente paso: ejecuta train_model.py")
    print("="*50)


if __name__ == "__main__":
    main()