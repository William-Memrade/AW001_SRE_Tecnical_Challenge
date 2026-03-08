#!/usr/bin/env python3
import sys
import re
import os

filename = sys.argv[1]

if not os.path.exists(filename):
    print(f"Error: {filename} no encontrado. Asegurate de generar el YAML de KOps primero.", file=sys.stderr)
    sys.exit(1)

with open(filename, "r") as f:
    text = f.read()

# Validar si ya fue modificado
if "dns: {}" in text:
    print("El archivo ya tiene configurado el acceso por DNS. No se requiere remover LoadBalancer.")
    sys.exit(0)

# Aplicar Regex para remover loadBalancer y cambiarlo a dns
new_text = re.sub(r"loadBalancer:.*?\n(      [a-z].*?\n)*", "dns: {}\n", text)

with open(filename, "w") as f:
    f.write(new_text)

print(f"Éxito: LoadBalancer removido de {filename} y reemplazado por acceso DNS.")
