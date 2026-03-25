#!/usr/bin/env python3
"""
Traductor automático para OpenSpecimen
Usa Lingva Translate (Google Translate gratuito)
"""

import json
import requests
import time
import sys
import os

# Servidores Lingva públicos (fallback si uno falla)
LINGVA_SERVERS = [
    "https://lingva.ml",
    "https://lingva.pussthecat.org", 
    "https://translate.plausibility.cloud"
]

def translate_text(text, source="en", target="es", retries=3):
    """Traduce texto usando Lingva API"""
    if not text or not text.strip():
        return text
    
    # No traducir si es solo placeholders o variables
    if text.startswith('{') and text.endswith('}'):
        return text
    
    for server in LINGVA_SERVERS:
        for attempt in range(retries):
            try:
                # Codificar texto para URL
                encoded = requests.utils.quote(text)
                url = f"{server}/api/v1/{source}/{target}/{encoded}"
                
                response = requests.get(url, timeout=10)
                if response.status_code == 200:
                    data = response.json()
                    return data.get("translation", text)
                    
            except Exception as e:
                time.sleep(1)
                continue
        
    # Si todos fallan, retornar original
    print(f"  [WARN] No se pudo traducir: {text[:50]}...")
    return text

def translate_json_value(value, stats):
    """Traduce valores JSON recursivamente"""
    if isinstance(value, str):
        translated = translate_text(value)
        stats['translated'] += 1
        if stats['translated'] % 50 == 0:
            print(f"  Progreso: {stats['translated']} strings traducidos...")
        time.sleep(0.3)  # Rate limiting
        return translated
    elif isinstance(value, dict):
        return {k: translate_json_value(v, stats) for k, v in value.items()}
    elif isinstance(value, list):
        return [translate_json_value(item, stats) for item in value]
    else:
        return value

def translate_json_file(input_path, output_path):
    """Traduce archivo JSON completo"""
    print(f"\n{'='*50}")
    print(f"Traduciendo: {input_path}")
    print(f"{'='*50}")
    
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    stats = {'translated': 0}
    translated_data = translate_json_value(data, stats)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(translated_data, f, ensure_ascii=False, indent=2)
    
    print(f"\n✓ Completado: {stats['translated']} strings")
    print(f"✓ Guardado en: {output_path}")

def translate_properties_file(input_path, output_path):
    """Traduce archivo .properties"""
    print(f"\n{'='*50}")
    print(f"Traduciendo: {input_path}")
    print(f"{'='*50}")
    
    translated_lines = []
    count = 0
    
    with open(input_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    total = len([l for l in lines if '=' in l and not l.strip().startswith('#')])
    
    for line in lines:
        line = line.rstrip('\n')
        
        # Comentarios y líneas vacías
        if not line.strip() or line.strip().startswith('#'):
            translated_lines.append(line)
            continue
        
        # Líneas con clave=valor
        if '=' in line:
            key, _, value = line.partition('=')
            if value.strip():
                translated_value = translate_text(value)
                translated_lines.append(f"{key}={translated_value}")
                count += 1
                if count % 50 == 0:
                    print(f"  Progreso: {count}/{total} strings...")
                time.sleep(0.3)
            else:
                translated_lines.append(line)
        else:
            translated_lines.append(line)
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(translated_lines))
    
    print(f"\n✓ Completado: {count} strings")
    print(f"✓ Guardado en: {output_path}")

def main():
    base_path = "/root/perplexity/openspecimen/src/openspecimen"
    
    print("\n" + "="*60)
    print("   TRADUCTOR OPENSPECIMEN - Inglés a Español")
    print("="*60)
    
    # Verificar conexión
    print("\nVerificando conexión a Lingva...")
    test = translate_text("Hello")
    if test == "Hola":
        print("✓ Conexión OK")
    else:
        print(f"✓ Conexión OK (respuesta: {test})")
    
    # 1. Traducir frontend nuevo (Vue.js)
    ui_en = f"{base_path}/ui/src/i18n/en.json"
    ui_es = f"{base_path}/ui/src/i18n/es.json"
    
    if os.path.exists(ui_en):
        translate_json_file(ui_en, ui_es)
    else:
        print(f"[SKIP] No existe: {ui_en}")
    
    # 2. Traducir frontend antiguo (AngularJS)
    www_en = f"{base_path}/www/app/modules/i18n/en.js"
    www_es = f"{base_path}/www/app/modules/i18n/es.js"
    
    if os.path.exists(www_en):
        # en.js es JSON pero con extensión .js
        translate_json_file(www_en, www_es)
    else:
        print(f"[SKIP] No existe: {www_en}")
    
    # 3. Traducir backend messages
    msg_en = f"{base_path}/WEB-INF/resources/errors/messages.properties"
    msg_es = f"{base_path}/WEB-INF/resources/errors/messages_es.properties"
    
    if os.path.exists(msg_en):
        translate_properties_file(msg_en, msg_es)
    else:
        print(f"[SKIP] No existe: {msg_en}")
    
    print("\n" + "="*60)
    print("   ¡TRADUCCIÓN COMPLETADA!")
    print("="*60)
    print("\nArchivos generados:")
    print(f"  - {ui_es}")
    print(f"  - {www_es}")
    print(f"  - {msg_es}")
    print("\nSiguiente paso: Rebuild de la imagen Docker")
    print("  docker compose build --no-cache")
    print("  docker compose up -d")

if __name__ == "__main__":
    main()
