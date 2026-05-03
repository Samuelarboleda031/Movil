# Configuración de Deep Links para Recuperación de Contraseña

Esta guía explica cómo configurar los deep links para que los emails de recuperación de contraseña puedan abrirse en la app móvil o en la web según corresponda.

## Arquitectura

```
📩 Email → link de Vercel (https://manitobarbershop.vercel.app/reset-password?code=xxx&email=xxx)
         ↓
   ┌─────┴─────┐
   ↓           ↓
[App Mobile]  [Web Vercel]
   ↑
   └─────── Si la app no está instalada → abre la página web
```

## Archivos Creados

### 1. Configuración Android (`AndroidManifest.xml`)
- App Links para `https://manitobarbershop.vercel.app/reset-password`
- Custom URL scheme `manitobarbershop://reset-password` como fallback

### 2. Configuración iOS
- **Runner.entitlements**: Universal Links para `manitobarbershop.vercel.app`
- **Info.plist**: Custom URL scheme `manitobarbershop`

### 3. Página Web Vercel
- **web/reset-password.html**: Página para resetear contraseña desde el navegador
- Intenta abrir la app automáticamente si está instalada
- Fallback al formulario web si no hay app

### 4. Archivos de Verificación
- **web/.well-known/assetlinks.json**: Para Android App Links
- **web/.well-known/apple-app-site-association**: Para iOS Universal Links

## Pasos para Completar la Configuración

### Android

1. **Obtener el SHA256 del certificado de firma**:
```bash
cd android
./gradlew signingReport
```

2. **Actualizar assetlinks.json** (`web/.well-known/assetlinks.json`):
```json
{
  "relation": ["delegate_permission/common.handle_all_urls"],
  "target": {
    "namespace": "android_app",
    "package_name": "com.example.parte_movil",
    "sha256_cert_fingerprints": [
      "XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX:XX"
    ]
  }
}
```

3. **Deploy a Vercel** para que el archivo esté disponible en:
   `https://manitobarbershop.vercel.app/.well-known/assetlinks.json`

### iOS

1. **Obtener Team ID** desde [Apple Developer Portal](https://developer.apple.com/account)

2. **Actualizar apple-app-site-association** (`web/.well-known/apple-app-site-association`):
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "ABCD123456.com.example.parteMovil",
        "paths": ["/reset-password", "/reset-password/*"]
      }
    ]
  }
}
```

3. **Habilitar "Associated Domains"** en Xcode:
   - Seleccionar el proyecto → Signing & Capabilities
   - Agregar "Associated Domains" capability
   - Agregar: `applinks:manitobarbershop.vercel.app`

4. **Deploy a Vercel**

### Backend API

El backend necesita estos endpoints:

1. **POST** `/api/Notificaciones/password-reset`
```json
{
  "email": "usuario@ejemplo.com",
  "nombre": "Juan Pérez",
  "resetCode": "codigo-generado",
  "resetLink": "https://manitobarbershop.vercel.app/reset-password?code=xxx&email=xxx",
  "appName": "Manito BarberShop",
  "expirationMinutes": 60
}
```

2. **POST** `/api/Auth/verify-reset-code`
```json
{
  "email": "usuario@ejemplo.com",
  "code": "codigo-recibido"
}
```

3. **POST** `/api/Auth/reset-password`
```json
{
  "email": "usuario@ejemplo.com",
  "code": "codigo-recibido",
  "newPassword": "nuevaContraseña123"
}
```

## Verificación

### Probar en Android
```bash
# Con la app instalada, ejecutar:
adb shell am start -W -a android.intent.action.VIEW -d "https://manitobarbershop.vercel.app/reset-password?code=test123&email=test@test.com" com.example.parte_movil
```

### Probar en iOS Simulator
```bash
# Con la app instalada, ejecutar:
xcrun simctl openurl booted "https://manitobarbershop.vercel.app/reset-password?code=test123&email=test@test.com"
```

### Probar Custom URL Scheme
```bash
# Android:
adb shell am start -W -a android.intent.action.VIEW -d "manitobarbershop://reset-password?code=test123&email=test@test.com"

# iOS:
xcrun simctl openurl booted "manitobarbershop://reset-password?code=test123&email=test@test.com"
```

## Solución de Problemas

### App Links no funcionan en Android
1. Verificar que `assetlinks.json` está accesible sin redirecciones
2. Verificar el SHA256 del certificado
3. Verificar que el package name coincide exactamente
4. Reinstalar la app después de hacer cambios

### Universal Links no funcionan en iOS
1. Verificar que el archivo `apple-app-site-association` no tiene extensión `.json`
2. Verificar que el Content-Type es `application/json`
3. Verificar que el Team ID y Bundle ID son correctos
4. Reinstalar la app después de hacer cambios

### La web no redirige a la app
1. Verificar que el esquema custom URL está definido correctamente
2. Probar manualmente con `window.location.href = 'manitobarbershop://reset-password'`

## Notas Importantes

- Los App Links (Android) y Universal Links (iOS) requieren HTTPS
- El dominio debe ser el mismo en la app y en los archivos de verificación
- El fallback a la web funciona automáticamente cuando la app no está instalada
