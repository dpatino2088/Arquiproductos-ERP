#!/bin/bash

# Script para verificar la configuración del entorno
# Uso: ./scripts/check-env.sh

echo "🔍 Verificando configuración del entorno..."
echo ""

# Verificar que estamos en la raíz del proyecto
if [ ! -f "package.json" ]; then
    echo "❌ Error: Este script debe ejecutarse desde la raíz del proyecto"
    exit 1
fi

# Verificar archivo .env.local
if [ -f ".env.local" ]; then
    echo "✅ Archivo .env.local existe"
    
    # Verificar VITE_SUPABASE_URL
    if grep -q "VITE_SUPABASE_URL=" .env.local; then
        URL=$(grep "VITE_SUPABASE_URL=" .env.local | cut -d '=' -f2)
        if [ -n "$URL" ] && [ "$URL" != "" ]; then
            echo "✅ VITE_SUPABASE_URL está configurado: ${URL:0:30}..."
        else
            echo "❌ VITE_SUPABASE_URL está vacío"
        fi
    else
        echo "❌ VITE_SUPABASE_URL no encontrado en .env.local"
    fi
    
    # Verificar VITE_SUPABASE_ANON_KEY
    if grep -q "VITE_SUPABASE_ANON_KEY=" .env.local; then
        KEY=$(grep "VITE_SUPABASE_ANON_KEY=" .env.local | cut -d '=' -f2)
        if [ -n "$KEY" ] && [ "$KEY" != "" ]; then
            if [[ "$KEY" == eyJ* ]]; then
                echo "✅ VITE_SUPABASE_ANON_KEY está configurado (formato JWT correcto)"
            else
                echo "⚠️  VITE_SUPABASE_ANON_KEY existe pero no tiene formato JWT (debe empezar con 'eyJ')"
            fi
        else
            echo "❌ VITE_SUPABASE_ANON_KEY está vacío"
        fi
    else
        echo "❌ VITE_SUPABASE_ANON_KEY no encontrado en .env.local"
    fi
else
    echo "❌ Archivo .env.local NO existe"
    echo ""
    echo "📝 Crea el archivo .env.local con:"
    echo "   VITE_SUPABASE_URL=https://tu-proyecto.supabase.co"
    echo "   VITE_SUPABASE_ANON_KEY=tu-clave-anon-public"
    exit 1
fi

echo ""
echo "🔍 Verificando servidor de desarrollo..."

# Verificar si el puerto 5173 está en uso
if lsof -Pi :5173 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "✅ Puerto 5173 está en uso (servidor corriendo)"
    echo "   Accede a: http://localhost:5173"
else
    echo "⚠️  Puerto 5173 no está en uso"
    echo "   Ejecuta: npm run dev"
fi

echo ""
echo "✅ Verificación completada"






