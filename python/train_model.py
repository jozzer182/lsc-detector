# ============================================================
# train_model.py
# Entrenamiento y exportación del modelo LSC MVP (A / B)
# Input:  dataset.csv  (generado por collect_data.py)
# Output: sign_model.tflite + labels.txt
# ============================================================

import os
import csv
import numpy as np
import pandas as pd
import tensorflow as tf
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix

# ─────────────────────────────────────────────
# CONFIGURACIÓN
# ─────────────────────────────────────────────
DATASET_FILE   = "dataset.csv"
MODEL_OUTPUT   = "sign_model.tflite"
LABELS_OUTPUT  = "labels.txt"
EPOCHS         = 50
BATCH_SIZE     = 8
TEST_SIZE      = 0.2    # 20% para validación
RANDOM_SEED    = 42


# ─────────────────────────────────────────────
# 1. CARGAR Y VALIDAR DATOS
# ─────────────────────────────────────────────
def load_dataset(filepath):
    print(f"\n📂 Cargando dataset: {filepath}")

    if not os.path.exists(filepath):
        print(f"❌ No se encontró {filepath}")
        print("   Asegúrate de haber corrido collect_data.py primero.")
        exit(1)

    df = pd.read_csv(filepath)

    # Verificar estructura
    if df.shape[1] != 64:  # 63 landmarks + 1 label
        print(f"❌ El CSV tiene {df.shape[1]} columnas, se esperaban 64 (63 landmarks + label)")
        exit(1)

    X = df.iloc[:, :63].values.astype(np.float32)
    y = df.iloc[:, 63].values

    # Resumen
    print(f"\n📊 Dataset cargado:")
    labels_found = np.unique(y)
    for label in labels_found:
        count = np.sum(y == label)
        print(f"   '{label}': {count} muestras")
    print(f"   Total: {len(y)} muestras")

    if len(labels_found) < 2:
        print("\n⚠️  Solo hay una clase en el dataset.")
        print("   Necesitas muestras de al menos 2 letras.")
        exit(1)

    return X, y, labels_found


# ─────────────────────────────────────────────
# 2. PREPROCESAMIENTO
# ─────────────────────────────────────────────
def preprocess(X, y):
    print("\n⚙️  Preprocesando datos...")

    # Normalización min-max por muestra
    # Centra los landmarks respecto a la muñeca (punto 0)
    X_norm = X.copy()
    for i in range(len(X_norm)):
        wrist_x = X_norm[i, 0]
        wrist_y = X_norm[i, 1]
        wrist_z = X_norm[i, 2]
        for j in range(21):
            X_norm[i, j*3]     -= wrist_x
            X_norm[i, j*3 + 1] -= wrist_y
            X_norm[i, j*3 + 2] -= wrist_z

        # Escalar para que sea invariante al tamaño de la mano
        max_val = np.max(np.abs(X_norm[i]))
        if max_val > 0:
            X_norm[i] /= max_val

    le = LabelEncoder()
    y_encoded = le.fit_transform(y)

    print(f"   Clases: {list(le.classes_)}")
    print(f"   Mapeo: { {c: i for i, c in enumerate(le.classes_)} }")

    return X_norm, y_encoded, le


# ─────────────────────────────────────────────
# 3. CONSTRUIR MODELO
# ─────────────────────────────────────────────
def build_model(num_classes):
    print(f"\n🧠 Construyendo modelo ({num_classes} clases)...")

    model = tf.keras.Sequential([
        tf.keras.layers.Input(shape=(63,)),

        tf.keras.layers.Dense(128, activation='relu'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.4),

        tf.keras.layers.Dense(64, activation='relu'),
        tf.keras.layers.BatchNormalization(),
        tf.keras.layers.Dropout(0.3),

        tf.keras.layers.Dense(32, activation='relu'),
        tf.keras.layers.Dropout(0.2),

        tf.keras.layers.Dense(num_classes, activation='softmax'),
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )

    model.summary()
    return model


# ─────────────────────────────────────────────
# 4. ENTRENAR
# ─────────────────────────────────────────────
def train(model, X_train, y_train, X_val, y_val):
    print(f"\n🏋️  Entrenando...")
    print(f"   Train: {len(X_train)} muestras | Val: {len(X_val)} muestras\n")

    callbacks = [
        # Para si el modelo deja de mejorar
        tf.keras.callbacks.EarlyStopping(
            monitor='val_accuracy',
            patience=10,
            restore_best_weights=True,
            verbose=1
        ),
        # Reducir learning rate si se estanca
        tf.keras.callbacks.ReduceLROnPlateau(
            monitor='val_loss',
            factor=0.5,
            patience=5,
            min_lr=1e-6,
            verbose=1
        ),
    ]

    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=EPOCHS,
        batch_size=BATCH_SIZE,
        callbacks=callbacks,
        verbose=1
    )

    return history


# ─────────────────────────────────────────────
# 5. EVALUAR
# ─────────────────────────────────────────────
def evaluate(model, X_val, y_val, le):
    print("\n📈 Evaluación final:")

    loss, acc = model.evaluate(X_val, y_val, verbose=0)
    print(f"   Loss:     {loss:.4f}")
    print(f"   Accuracy: {acc*100:.1f}%")

    y_pred = np.argmax(model.predict(X_val, verbose=0), axis=1)

    print("\n📋 Reporte por clase:")
    print(classification_report(y_val, y_pred, target_names=le.classes_))

    print("🔢 Matriz de confusión:")
    cm = confusion_matrix(y_val, y_pred)
    header = "     " + "  ".join(f"{c:>4}" for c in le.classes_)
    print(header)
    for i, row in enumerate(cm):
        row_str = "  ".join(f"{v:>4}" for v in row)
        print(f"  {le.classes_[i]:>3}  {row_str}")

    if acc < 0.80:
        print("\n⚠️  Accuracy menor al 80% — considera:")
        print("   - Agregar más muestras (50+ por clase)")
        print("   - Variar más la posición/ángulo de la mano al grabar")

    return acc


# ─────────────────────────────────────────────
# 6. EXPORTAR A TFLITE
# ─────────────────────────────────────────────
def export_tflite(model, le, model_path, labels_path):
    print(f"\n📦 Exportando a TFLite...")

    # Convertir
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Optimización: reduce tamaño del modelo ~4x sin perder precisión notable
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    tflite_model = converter.convert()

    # Guardar modelo
    with open(model_path, "wb") as f:
        f.write(tflite_model)

    size_kb = os.path.getsize(model_path) / 1024
    print(f"   ✅ Modelo: {model_path} ({size_kb:.1f} KB)")

    # Guardar etiquetas
    with open(labels_path, "w") as f:
        f.write("\n".join(le.classes_))

    print(f"   ✅ Etiquetas: {labels_path}")
    print(f"   Clases en orden: {list(le.classes_)}")


# ─────────────────────────────────────────────
# 7. VERIFICAR MODELO EXPORTADO
# ─────────────────────────────────────────────
def verify_tflite(model_path, X_val, y_val, le):
    print(f"\n🔍 Verificando modelo TFLite exportado...")

    interpreter = tf.lite.Interpreter(model_path=model_path)
    interpreter.allocate_tensors()

    input_details  = interpreter.get_input_details()
    output_details = interpreter.get_output_details()

    correct = 0
    for i in range(min(10, len(X_val))):  # testea 10 muestras
        input_data = np.expand_dims(X_val[i], axis=0).astype(np.float32)
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()
        output = interpreter.get_tensor(output_details[0]['index'])

        pred_idx  = np.argmax(output[0])
        pred_label = le.classes_[pred_idx]
        real_label = le.classes_[y_val[i]]
        confidence = output[0][pred_idx] * 100

        status = "✅" if pred_idx == y_val[i] else "❌"
        print(f"   {status}  Real: {real_label:>2}  |  Pred: {pred_label:>2}  |  Confianza: {confidence:.1f}%")
        if pred_idx == y_val[i]:
            correct += 1

    print(f"\n   Precisión en muestra de verificación: {correct}/10")


# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
def main():
    print("╔══════════════════════════════════════╗")
    print("║   LSC Model Trainer — MVP (A / B)    ║")
    print("╚══════════════════════════════════════╝")

    # 1. Cargar datos
    X, y, labels = load_dataset(DATASET_FILE)

    # 2. Preprocesar
    X_norm, y_encoded, le = preprocess(X, y)

    # 3. Split train/val
    X_train, X_val, y_train, y_val = train_test_split(
        X_norm, y_encoded,
        test_size=TEST_SIZE,
        random_state=RANDOM_SEED,
        stratify=y_encoded   # mantiene proporción de clases
    )

    # 4. Modelo
    model = build_model(num_classes=len(le.classes_))

    # 5. Entrenar
    history = train(model, X_train, y_train, X_val, y_val)

    # 6. Evaluar
    acc = evaluate(model, X_val, y_val, le)

    # 7. Exportar solo si la accuracy es razonable
    if acc >= 0.70:
        export_tflite(model, le, MODEL_OUTPUT, LABELS_OUTPUT)
        verify_tflite(MODEL_OUTPUT, X_val, y_val, le)

        print("\n" + "="*50)
        print("  ✅ TODO LISTO")
        print("="*50)
        print(f"  Archivos generados:")
        print(f"    📄 {MODEL_OUTPUT}  ← va en Flutter assets/")
        print(f"    📄 {LABELS_OUTPUT}  ← va en Flutter assets/")
        print(f"\n  Siguiente paso: integrar en la app Flutter")
        print("="*50)
    else:
        print("\n⚠️  Accuracy muy baja — modelo no exportado.")
        print("   Graba más muestras con collect_data.py y vuelve a intentar.")


if __name__ == "__main__":
    main()